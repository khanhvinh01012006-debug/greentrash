-- ============================================================================
-- update_02_hoa_don_nguoi_dung.sql
-- BỔ SUNG: Quản lý người dùng + Hóa đơn + Định mức vật tư mỗi lần thu gom
-- ----------------------------------------------------------------------------
-- Ánh xạ với báo cáo:
--   - UC22 Phân quyền người dùng   -> cột vai_tro (đã có) + cột bi_khoa (mới)
--   - BM04/UC16 Hóa đơn thanh toán -> bảng hoa_don (mới)
--   - CT_PHIEUTHUGOM_VATTU (3.2.10)-> bảng hoa_don_vat_tu (mới)
--   - UC07 Chọn vật tư thu gom     -> cột dinh_muc_su_dung của vat_tu (mới)
-- Cách chạy: copy toàn bộ -> SQL Editor -> Run. Dữ liệu cũ giữ nguyên 100%.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. NÂNG CẤP BẢNG CŨ BẰNG "ALTER TABLE ... ADD COLUMN IF NOT EXISTS"
--    (thêm cột mới, dữ liệu cũ không mất - chạy lại nhiều lần cũng an toàn)
-- ----------------------------------------------------------------------------

-- 1a. nguoi_dung: thêm cờ khóa tài khoản (false = hoạt động bình thường)
alter table public.nguoi_dung
  add column if not exists bi_khoa boolean not null default false;

-- 1b. vat_tu: thêm ĐỊNH MỨC SỬ DỤNG = số lượng tiêu hao cho MỖI LẦN thu gom
--     (0 = vật tư này không tiêu hao theo lần, ví dụ thùng chứa dùng lại được)
alter table public.vat_tu
  add column if not exists dinh_muc_su_dung int not null default 0
  check (dinh_muc_su_dung >= 0);

-- Gán định mức mẫu cho 3 vật tư có sẵn (chỉ chạy khi tất cả còn bằng 0
-- để không ghi đè nếu admin đã tự chỉnh)
update public.vat_tu
set dinh_muc_su_dung = case
      when ten_vat_tu = 'Túi phân loại rác' then 2  -- mỗi lần thu gom dùng 2 túi
      when ten_vat_tu = 'Găng tay bảo hộ'   then 1  -- 1 đôi găng tay
      else 0                                        -- thùng 60L dùng lại, không tiêu hao
    end
where not exists (select 1 from public.vat_tu where dinh_muc_su_dung > 0);

-- ----------------------------------------------------------------------------
-- 2. BẢNG hoa_don (bảng HOADON - mục 3.2.11, biểu mẫu BM04)
--    Mỗi lịch HOÀN TẤT sinh đúng 1 hóa đơn (ràng buộc UNIQUE ma_lich)
-- ----------------------------------------------------------------------------
create table if not exists public.hoa_don (
  id bigint generated always as identity primary key,

  -- 1 lịch <-> 1 hóa đơn. RESTRICT: không xóa được lịch đã có hóa đơn
  ma_lich bigint not null unique
          references public.lich_thu_gom(id) on delete restrict,

  tien_rac          numeric(12,0) not null default 0,  -- tiền theo khối lượng x đơn giá
  tong_tien_vat_tu  numeric(12,0) not null default 0,  -- tổng chi phí vật tư tiêu hao
  ngay_lap          timestamptz not null default now() -- thời điểm lập hóa đơn
);

-- ----------------------------------------------------------------------------
-- 3. BẢNG hoa_don_vat_tu (bảng CT_PHIEUTHUGOM_VATTU - mục 3.2.10)
--    Chi tiết vật tư đã tiêu hao cho từng hóa đơn.
--    LƯU Ý THIẾT KẾ: lưu kèm ten/don_vi/don_gia TẠI THỜI ĐIỂM LẬP (snapshot).
--    Nhờ vậy sau này admin đổi giá vật tư, hóa đơn cũ vẫn giữ nguyên số liệu
--    lịch sử - nguyên tắc quan trọng của chứng từ kế toán.
-- ----------------------------------------------------------------------------
create table if not exists public.hoa_don_vat_tu (
  id bigint generated always as identity primary key,

  -- CASCADE: xóa hóa đơn thì các dòng chi tiết xóa theo
  ma_hoa_don bigint not null
             references public.hoa_don(id) on delete cascade,

  -- SET NULL: lỡ vật tư gốc bị xóa khỏi danh mục, dòng lịch sử vẫn còn
  ma_vat_tu  bigint references public.vat_tu(id) on delete set null,

  ten_vat_tu  text not null,           -- snapshot tên vật tư
  don_vi_tinh text not null,           -- snapshot đơn vị tính
  so_luong    int  not null check (so_luong > 0),
  don_gia     numeric(12,0) not null,  -- snapshot đơn giá lúc lập
  thanh_tien  numeric(12,0) not null   -- = so_luong x don_gia
);

-- ----------------------------------------------------------------------------
-- 4. PHÂN QUYỀN (RLS): khách chỉ xem hóa đơn của lịch MÌNH đặt, admin toàn quyền
-- ----------------------------------------------------------------------------
alter table public.hoa_don         enable row level security;
alter table public.hoa_don_vat_tu  enable row level security;

drop policy if exists "xem hoa don cua minh hoac admin" on public.hoa_don;
create policy "xem hoa don cua minh hoac admin"
  on public.hoa_don for select
  using (
    la_admin()
    or exists (               -- hóa đơn thuộc lịch do chính mình đặt
      select 1 from public.lich_thu_gom l
      where l.id = ma_lich and l.ma_khach_hang = auth.uid()
    )
  );

drop policy if exists "chi admin lap hoa don" on public.hoa_don;
create policy "chi admin lap hoa don"
  on public.hoa_don for insert
  with check (la_admin());

drop policy if exists "xem chi tiet vat tu hoa don" on public.hoa_don_vat_tu;
create policy "xem chi tiet vat tu hoa don"
  on public.hoa_don_vat_tu for select
  using (
    la_admin()
    or exists (               -- lần theo: chi tiết -> hóa đơn -> lịch -> mình
      select 1
      from public.hoa_don hd
      join public.lich_thu_gom l on l.id = hd.ma_lich
      where hd.id = ma_hoa_don and l.ma_khach_hang = auth.uid()
    )
  );

drop policy if exists "chi admin ghi chi tiet hoa don" on public.hoa_don_vat_tu;
create policy "chi admin ghi chi tiet hoa don"
  on public.hoa_don_vat_tu for insert
  with check (la_admin());
