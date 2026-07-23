-- ============================================================================
-- GREENTRASH - SCHEMA DATABASE (Supabase / PostgreSQL)
-- Nhóm 30 - Đặt Lịch Thu Gom Rác Tại Nhà
--
-- CÁCH CHẠY:
--   1. Vào https://supabase.com -> mở project của bạn
--   2. Menu trái chọn "SQL Editor" -> "New query"
--   3. Dán TOÀN BỘ nội dung file này vào -> bấm "Run"
--
-- LƯU Ý QUAN TRỌNG: File này dùng "CREATE TABLE IF NOT EXISTS" nên bạn có thể
-- chạy lại nhiều lần mà KHÔNG bị mất dữ liệu cũ. Khi muốn thêm cột mới sau này,
-- chỉ cần viết thêm lệnh: ALTER TABLE ten_bang ADD COLUMN ten_cot kieu_du_lieu;
-- => KHÔNG BAO GIỜ phải xóa database làm lại từ đầu.
-- ============================================================================


-- ============================================================================
-- BẢNG 1: nguoi_dung (gộp KHACHHANG + NHANVIEN + TAIKHOAN trong báo cáo)
-- ----------------------------------------------------------------------------
-- Supabase có sẵn hệ thống đăng nhập (bảng auth.users lưu email + mật khẩu
-- đã mã hóa). Bảng nguoi_dung này lưu THÔNG TIN THÊM của mỗi tài khoản:
-- họ tên, SĐT, địa chỉ, và quan trọng nhất là VAI TRÒ (khach_hang / admin)
-- để app biết hiển thị giao diện nào.
-- ============================================================================
CREATE TABLE IF NOT EXISTS nguoi_dung (
  -- id trùng với id trong bảng auth.users của Supabase (kiểu uuid)
  -- ON DELETE CASCADE: nếu tài khoản đăng nhập bị xóa thì hồ sơ này xóa theo
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  ho_ten        text NOT NULL,                 -- Họ tên người dùng
  so_dien_thoai text,                          -- SĐT liên hệ
  dia_chi       text,                          -- Địa chỉ thu gom mặc định
  email         text,                          -- Email (lưu thêm để hiện ra cho admin xem)

  -- Vai trò: 'khach_hang' hoặc 'admin'
  -- CHECK = ràng buộc miền giá trị, nhập sai sẽ báo lỗi ngay
  vai_tro text NOT NULL DEFAULT 'khach_hang'
          CHECK (vai_tro IN ('khach_hang', 'admin')),

  ngay_tao timestamptz NOT NULL DEFAULT now()  -- Ngày tạo tài khoản (tự điền)
);


-- ============================================================================
-- BẢNG 2: loai_rac (bảng LOAIRAC trong báo cáo - mục 3.2.5)
-- ----------------------------------------------------------------------------
-- Danh mục loại rác + đơn giá thu gom. Admin quản lý bảng này.
-- Khách hàng xem để chọn khi đặt lịch.
-- ============================================================================
CREATE TABLE IF NOT EXISTS loai_rac (
  -- bigint GENERATED ALWAYS AS IDENTITY = số tự tăng 1,2,3... (giống AUTO_INCREMENT)
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  ten_loai_rac text NOT NULL,                  -- VD: 'Rác sinh hoạt', 'Rác tái chế'
  don_gia      numeric(12,0) NOT NULL CHECK (don_gia > 0),  -- Đơn giá / kg (VNĐ)
  mo_ta        text,                           -- Mô tả / lưu ý xử lý
  ngay_tao     timestamptz NOT NULL DEFAULT now()
);


-- ============================================================================
-- BẢNG 3: vat_tu (bảng VATTU trong báo cáo - mục 3.2.6)
-- ----------------------------------------------------------------------------
-- Kho vật tư: túi phân loại, găng tay, thùng chứa... Admin nhập/xuất kho
-- bằng cách cộng/trừ so_luong_ton.
-- ============================================================================
CREATE TABLE IF NOT EXISTS vat_tu (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  ten_vat_tu   text NOT NULL,                              -- Tên vật tư
  don_vi_tinh  text NOT NULL DEFAULT 'cái',                -- Đơn vị tính
  so_luong_ton int  NOT NULL DEFAULT 0 CHECK (so_luong_ton >= 0),  -- Tồn kho, không âm
  ton_toi_thieu int NOT NULL DEFAULT 10,                   -- Ngưỡng cảnh báo sắp hết
  don_gia      numeric(12,0) NOT NULL DEFAULT 0,           -- Đơn giá vật tư
  ngay_tao     timestamptz NOT NULL DEFAULT now()
);


-- ============================================================================
-- BẢNG 4: lich_thu_gom (bảng LICHTHUGOM - mục 3.2.8, biểu mẫu BM01)
-- ----------------------------------------------------------------------------
-- Bảng QUAN TRỌNG NHẤT: mỗi dòng = 1 lịch hẹn thu gom của khách hàng.
-- Có cột hinh_anh_url để lưu link ảnh rác mà khách chụp khi đặt lịch.
-- ============================================================================
CREATE TABLE IF NOT EXISTS lich_thu_gom (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  -- Khóa ngoại (FK) trỏ tới người đặt lịch
  ma_khach_hang uuid NOT NULL REFERENCES nguoi_dung(id) ON DELETE CASCADE,

  -- Khóa ngoại trỏ tới loại rác được chọn
  -- ON DELETE RESTRICT: không cho xóa loại rác nếu đang có lịch dùng nó
  ma_loai_rac bigint NOT NULL REFERENCES loai_rac(id) ON DELETE RESTRICT,

  dia_chi_thu_gom    text NOT NULL,            -- Địa chỉ thu gom
  ngay_hen           date NOT NULL,            -- Ngày hẹn thu gom
  khung_gio          text NOT NULL DEFAULT 'sang'
                     CHECK (khung_gio IN ('sang', 'chieu')),   -- Khung giờ (QD trong báo cáo)
  khoi_luong_uoc_tinh numeric(8,1) CHECK (khoi_luong_uoc_tinh > 0),  -- Kg ước tính

  -- Chi phí dự kiến = khối lượng x đơn giá (app tự tính khi đặt lịch)
  chi_phi_du_kien numeric(12,0) NOT NULL DEFAULT 0,

  -- Link ảnh rác khách chụp, lưu trên Supabase Storage. Cho phép NULL (không bắt buộc)
  hinh_anh_url text,

  ghi_chu text,                                -- Ghi chú thêm của khách

  -- Trạng thái xử lý (theo mục 3.2.8 của báo cáo):
  -- cho_xac_nhan -> admin duyệt -> da_xac_nhan -> thu gom xong -> hoan_tat
  -- hoặc bị hủy -> da_huy
  trang_thai text NOT NULL DEFAULT 'cho_xac_nhan'
             CHECK (trang_thai IN ('cho_xac_nhan', 'da_xac_nhan', 'hoan_tat', 'da_huy')),

  ngay_dat timestamptz NOT NULL DEFAULT now()  -- Thời điểm đặt lịch (tự điền)
);

-- INDEX = "mục lục" giúp truy vấn nhanh hơn (mục 3.4 báo cáo - tối ưu tốc độ)
CREATE INDEX IF NOT EXISTS idx_lich_theo_khach  ON lich_thu_gom (ma_khach_hang);
CREATE INDEX IF NOT EXISTS idx_lich_theo_trangthai ON lich_thu_gom (trang_thai);


-- ============================================================================
-- BẢNG 5: danh_gia (bảng DANHGIA - mục 3.2.18, biểu mẫu BM09)
-- ----------------------------------------------------------------------------
-- Khách hàng đánh giá dịch vụ sau khi lịch hoàn tất. 1 lịch chỉ đánh giá 1 lần
-- (ràng buộc UNIQUE ở cột ma_lich).
-- ============================================================================
CREATE TABLE IF NOT EXISTS danh_gia (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  ma_lich bigint NOT NULL UNIQUE REFERENCES lich_thu_gom(id) ON DELETE CASCADE,
  ma_khach_hang uuid NOT NULL REFERENCES nguoi_dung(id) ON DELETE CASCADE,

  so_sao   int NOT NULL CHECK (so_sao BETWEEN 1 AND 5),  -- Điểm 1-5 sao
  nhan_xet text,                                          -- Nhận xét (không bắt buộc)
  ngay_danh_gia timestamptz NOT NULL DEFAULT now()
);


-- ============================================================================
-- PHẦN BẢO MẬT: ROW LEVEL SECURITY (RLS)
-- ----------------------------------------------------------------------------
-- RLS = luật quy định AI được đọc/ghi dòng nào. Nếu không bật RLS, bất kỳ ai
-- có link project cũng đọc được toàn bộ dữ liệu -> rất nguy hiểm.
-- Quy tắc chung ở đây:
--   - Khách hàng: chỉ thấy & sửa dữ liệu CỦA MÌNH
--   - Admin: thấy & sửa TẤT CẢ
--   - Danh mục (loai_rac, vat_tu): ai đăng nhập cũng xem được, chỉ admin sửa
-- ============================================================================

-- Hàm tiện ích: kiểm tra người đang đăng nhập có phải admin không.
-- auth.uid() = id của người đang đăng nhập (Supabase cung cấp sẵn).
-- SECURITY DEFINER để hàm chạy được bên trong các policy mà không bị kẹt RLS.
CREATE OR REPLACE FUNCTION la_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM nguoi_dung
    WHERE id = auth.uid() AND vai_tro = 'admin'
  );
$$;

-- Bật RLS cho từng bảng
ALTER TABLE nguoi_dung   ENABLE ROW LEVEL SECURITY;
ALTER TABLE loai_rac     ENABLE ROW LEVEL SECURITY;
ALTER TABLE vat_tu       ENABLE ROW LEVEL SECURITY;
ALTER TABLE lich_thu_gom ENABLE ROW LEVEL SECURITY;
ALTER TABLE danh_gia     ENABLE ROW LEVEL SECURITY;

-- ---------- Luật cho bảng nguoi_dung ----------
DROP POLICY IF EXISTS "xem ho so cua minh hoac admin xem het" ON nguoi_dung;
CREATE POLICY "xem ho so cua minh hoac admin xem het" ON nguoi_dung
  FOR SELECT USING (id = auth.uid() OR la_admin());

DROP POLICY IF EXISTS "tu tao ho so khi dang ky" ON nguoi_dung;
CREATE POLICY "tu tao ho so khi dang ky" ON nguoi_dung
  FOR INSERT WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "tu sua ho so cua minh" ON nguoi_dung;
CREATE POLICY "tu sua ho so cua minh" ON nguoi_dung
  FOR UPDATE USING (id = auth.uid() OR la_admin());

-- ---------- Luật cho bảng loai_rac (danh mục công khai) ----------
DROP POLICY IF EXISTS "ai dang nhap cung xem duoc loai rac" ON loai_rac;
CREATE POLICY "ai dang nhap cung xem duoc loai rac" ON loai_rac
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "chi admin duoc sua loai rac" ON loai_rac;
CREATE POLICY "chi admin duoc sua loai rac" ON loai_rac
  FOR ALL USING (la_admin()) WITH CHECK (la_admin());

-- ---------- Luật cho bảng vat_tu ----------
DROP POLICY IF EXISTS "ai dang nhap cung xem duoc vat tu" ON vat_tu;
CREATE POLICY "ai dang nhap cung xem duoc vat tu" ON vat_tu
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "chi admin duoc sua vat tu" ON vat_tu;
CREATE POLICY "chi admin duoc sua vat tu" ON vat_tu
  FOR ALL USING (la_admin()) WITH CHECK (la_admin());

-- ---------- Luật cho bảng lich_thu_gom ----------
DROP POLICY IF EXISTS "xem lich cua minh hoac admin xem het" ON lich_thu_gom;
CREATE POLICY "xem lich cua minh hoac admin xem het" ON lich_thu_gom
  FOR SELECT USING (ma_khach_hang = auth.uid() OR la_admin());

DROP POLICY IF EXISTS "khach tu dat lich cho minh" ON lich_thu_gom;
CREATE POLICY "khach tu dat lich cho minh" ON lich_thu_gom
  FOR INSERT WITH CHECK (ma_khach_hang = auth.uid());

DROP POLICY IF EXISTS "sua lich cua minh hoac admin sua het" ON lich_thu_gom;
CREATE POLICY "sua lich cua minh hoac admin sua het" ON lich_thu_gom
  FOR UPDATE USING (ma_khach_hang = auth.uid() OR la_admin());

-- ---------- Luật cho bảng danh_gia ----------
DROP POLICY IF EXISTS "xem danh gia" ON danh_gia;
CREATE POLICY "xem danh gia" ON danh_gia
  FOR SELECT USING (ma_khach_hang = auth.uid() OR la_admin());

DROP POLICY IF EXISTS "khach tu danh gia" ON danh_gia;
CREATE POLICY "khach tu danh gia" ON danh_gia
  FOR INSERT WITH CHECK (ma_khach_hang = auth.uid());


-- ============================================================================
-- BẬT REALTIME cho bảng lich_thu_gom
-- ----------------------------------------------------------------------------
-- Nhờ dòng này, app Flutter dùng .stream() sẽ TỰ CẬP NHẬT giao diện ngay khi
-- admin đổi trạng thái lịch (không cần khách bấm refresh).
-- ============================================================================
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE lich_thu_gom;
EXCEPTION
  WHEN duplicate_object THEN NULL;  -- đã thêm rồi thì bỏ qua, không báo lỗi
END $$;


-- ============================================================================
-- DỮ LIỆU MẪU (chạy lần đầu cho có sẵn danh mục để test)
-- ON CONFLICT DO NOTHING không dùng được vì không có unique ten, nên ta kiểm
-- tra bảng trống mới chèn -> chạy lại file không bị nhân đôi dữ liệu.
-- ============================================================================
INSERT INTO loai_rac (ten_loai_rac, don_gia, mo_ta)
SELECT * FROM (VALUES
  ('Rác sinh hoạt',  5000::numeric,  'Rác thải hằng ngày của hộ gia đình'),
  ('Rác tái chế',    3000::numeric,  'Giấy, nhựa, kim loại có thể tái chế'),
  ('Rác cồng kềnh', 15000::numeric,  'Bàn ghế, nệm, tủ... kích thước lớn'),
  ('Rác nguy hại',  25000::numeric,  'Pin, bóng đèn, hóa chất - cần xử lý riêng')
) AS v(ten, gia, mota)
WHERE NOT EXISTS (SELECT 1 FROM loai_rac);

INSERT INTO vat_tu (ten_vat_tu, don_vi_tinh, so_luong_ton, ton_toi_thieu, don_gia)
SELECT * FROM (VALUES
  ('Túi phân loại rác', 'cái', 200, 50, 2000::numeric),
  ('Găng tay bảo hộ',   'đôi', 100, 20, 8000::numeric),
  ('Thùng chứa 60L',    'cái',  30, 10, 120000::numeric)
) AS v(ten, dvt, ton, min, gia)
WHERE NOT EXISTS (SELECT 1 FROM vat_tu);

-- ============================================================================
-- XONG! Sau khi chạy file này:
--   1. Vào menu "Storage" -> "New bucket" -> đặt tên: hinh-anh-rac
--      -> BẬT "Public bucket" -> Save  (để app hiển thị được ảnh)
--   2. Đăng ký 1 tài khoản trong app, rồi vào "Table Editor" -> bảng nguoi_dung
--      -> sửa cột vai_tro của tài khoản đó thành 'admin' để làm tài khoản quản trị
-- ============================================================================
