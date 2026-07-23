-- ============================================================================
-- update_01_bai_viet.sql - BỔ SUNG chức năng Tin tức / Bài viết
-- ----------------------------------------------------------------------------
-- ĐÂY CHÍNH LÀ ƯU ĐIỂM CỦA SUPABASE mà bạn cần: nâng cấp database bằng cách
-- chạy thêm file SQL mới, KHÔNG đụng chạm gì tới 5 bảng và dữ liệu đã có.
-- Cách chạy: copy toàn bộ file này -> SQL Editor -> Run (giống schema.sql)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Bảng bai_viet: admin đăng tin tức, khách đọc ở trang chủ
-- ----------------------------------------------------------------------------
create table if not exists public.bai_viet (
  id           bigint generated always as identity primary key,
  tieu_de      text not null,           -- tiêu đề bài viết
  tom_tat      text,                    -- 1-2 câu tóm tắt hiện ở danh sách
  noi_dung     text not null,           -- nội dung đầy đủ
  hinh_anh_url text,                    -- link ảnh bìa (upload lên Storage)
  ngay_dang    timestamptz not null default now() -- tự lấy giờ hiện tại
);

-- ----------------------------------------------------------------------------
-- 2. Bật bảo mật hàng (RLS) và phân quyền
--    - Ai đăng nhập cũng ĐỌC được bài viết
--    - Chỉ admin mới được THÊM / SỬA / XÓA
-- ----------------------------------------------------------------------------
alter table public.bai_viet enable row level security;

-- drop trước rồi create để chạy lại file này nhiều lần không bị lỗi trùng tên
drop policy if exists "ai cung doc duoc bai viet" on public.bai_viet;
create policy "ai cung doc duoc bai viet"
  on public.bai_viet for select
  to authenticated
  using (true);

drop policy if exists "chi admin quan ly bai viet" on public.bai_viet;
create policy "chi admin quan ly bai viet"
  on public.bai_viet for all
  to authenticated
  using (public.la_admin())        -- hàm la_admin() đã tạo trong schema.sql
  with check (public.la_admin());

-- ----------------------------------------------------------------------------
-- 3. Ba bài viết mẫu để trang chủ có nội dung ngay (ảnh demo từ picsum.photos,
--    sau này admin tự đăng bài với ảnh thật upload từ máy)
--    Chỉ chèn khi bảng đang trống -> chạy lại file không bị nhân đôi bài
-- ----------------------------------------------------------------------------
insert into public.bai_viet (tieu_de, tom_tat, noi_dung, hinh_anh_url)
select * from (values
  (
    'Vì sao nên phân loại rác tại nguồn?',
    'Phân loại rác ngay tại nhà giúp tăng gấp 3 lần lượng rác được tái chế thành công.',
    'Mỗi ngày, một hộ gia đình Việt Nam thải ra trung bình 1-2 kg rác. Nếu không phân loại, phần lớn số rác này sẽ được chôn lấp, gây ô nhiễm đất và nước ngầm trong hàng chục năm.' || chr(10) || chr(10) || 'Khi bạn phân loại rác tại nguồn: giấy, nhựa và kim loại sạch sẽ được đưa thẳng tới nhà máy tái chế thay vì bãi rác. Chi phí xử lý giảm, tài nguyên được tái sinh, và bạn còn nhận được tiền từ chính rác tái chế của mình thông qua GreenTrash.' || chr(10) || chr(10) || 'Hãy bắt đầu từ việc đơn giản nhất: đặt 3 túi riêng trong nhà cho giấy, nhựa và rác còn lại. Chỉ mất 1 phút mỗi ngày nhưng tác động tới môi trường là rất lớn.',
    'https://picsum.photos/seed/greentrash1/800/400'
  ),
  (
    'Mẹo xử lý chai nhựa đúng cách trước khi giao',
    'Đổ sạch - tháo nắp - bóp dẹp: công thức 3 bước giúp chai nhựa của bạn tái chế được 100%.',
    'Nhiều người không biết rằng một chai nhựa còn sót nước ngọt bên trong có thể làm hỏng cả một mẻ tái chế. Vì vậy trước khi giao cho GreenTrash, bạn hãy làm theo 3 bước sau:' || chr(10) || chr(10) || 'Bước 1: Đổ sạch chất lỏng còn lại, tráng nhanh qua nước nếu chai đựng sữa hoặc nước có đường.' || chr(10) || 'Bước 2: Tháo nắp và vòng nhựa ở cổ chai - chúng làm từ loại nhựa khác với thân chai.' || chr(10) || 'Bước 3: Bóp dẹp chai để tiết kiệm không gian vận chuyển, giúp mỗi chuyến xe chở được nhiều hơn, giảm khí thải.' || chr(10) || chr(10) || 'Kiểm tra thêm ký hiệu dưới đáy chai: số 1 (PET), 2 (HDPE), 4 (LDPE) và 5 (PP) đều tái chế được nhé!',
    'https://picsum.photos/seed/greentrash2/800/400'
  ),
  (
    'GreenTrash thu gom tận nhà - đặt lịch chỉ 30 giây',
    'Không cần chờ xe rác, không cần mang đi xa - chọn ngày giờ, chúng tôi đến tận cửa.',
    'Bạn có một thùng giấy carton sau khi chuyển nhà? Một bao chai nhựa sau bữa tiệc? Đừng vứt chung với rác sinh hoạt!' || chr(10) || chr(10) || 'Với GreenTrash, bạn chỉ cần: mở app, chọn loại rác, chọn ngày giờ thuận tiện, chụp một tấm ảnh và bấm Đặt lịch. Hệ thống sẽ báo giá dự kiến ngay lập tức dựa trên khối lượng bạn nhập.' || chr(10) || chr(10) || 'Nhân viên của chúng tôi sẽ đến đúng hẹn, cân đo tại chỗ và thanh toán cho bạn theo bảng giá công khai. Toàn bộ trạng thái đơn được cập nhật trực tiếp trên app - đặt xong là biết ngay khi nào được duyệt.',
    'https://picsum.photos/seed/greentrash3/800/400'
  )
) as bai_moi
where not exists (select 1 from public.bai_viet);
