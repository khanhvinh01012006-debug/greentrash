// ============================================================================
// database_service.dart - Mọi thao tác ĐỌC/GHI dữ liệu nghiệp vụ
// ----------------------------------------------------------------------------
// Bao gồm các chức năng theo báo cáo:
//   - UC04: Đặt lịch thu gom mới        - UC10: Sửa / Hủy lịch hẹn
//   - UC08: Theo dõi tiến độ (realtime)  - UC11: Tra cứu loại rác / vật tư
//   - UC12/13: Nhập / Xuất kho vật tư    - UC18: Báo cáo doanh thu
//   - BM09: Đánh giá dịch vụ             - Admin duyệt / từ chối lịch
// ============================================================================

import '../main.dart'; // dùng biến `supabase`

class DatabaseService {
  // ==========================================================================
  // PHẦN 0: HỒ SƠ CÁ NHÂN (bảng nguoi_dung)
  // ==========================================================================

  /// Lấy hồ sơ của người đang đăng nhập (họ tên, SĐT, địa chỉ, email...)
  /// Trả về null nếu chưa có hồ sơ (trường hợp hiếm)
  static Future<Map<String, dynamic>?> layHoSoCuaToi() async {
    final userId = supabase.auth.currentUser!.id;
    return await supabase
        .from('nguoi_dung')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  /// Cập nhật hồ sơ của chính mình (RLS chỉ cho sửa dòng có id = mình)
  /// Lưu ý: email KHÔNG cho sửa ở đây vì email gắn với tài khoản đăng nhập
  static Future<void> capNhatHoSo({
    required String hoTen,
    required String soDienThoai,
    required String diaChi,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('nguoi_dung').update({
      'ho_ten': hoTen,
      'so_dien_thoai': soDienThoai,
      'dia_chi': diaChi,
    }).eq('id', userId);
  }

  /// Lưu link ảnh đại diện vừa upload vào cột anh_dai_dien_url
  /// (cần chạy file supabase/update_04_anh_dai_dien.sql trước)
  static Future<void> capNhatAnhDaiDien(String urlAnh) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase
        .from('nguoi_dung')
        .update({'anh_dai_dien_url': urlAnh}).eq('id', userId);
  }

  // ==========================================================================
  // PHẦN 1: LOẠI RÁC (bảng loai_rac)
  // ==========================================================================

  /// Lấy danh sách tất cả loại rác (dùng cho dropdown khi đặt lịch + admin quản lý)
  static Future<List<Map<String, dynamic>>> layDanhSachLoaiRac() async {
    // .order('id') = sắp xếp theo id tăng dần cho ổn định
    return await supabase.from('loai_rac').select().order('id');
  }

  /// Admin: thêm loại rác mới
  static Future<void> themLoaiRac({
    required String ten,
    required num donGia,
    String? moTa,
  }) async {
    await supabase.from('loai_rac').insert({
      'ten_loai_rac': ten,
      'don_gia': donGia,
      'mo_ta': moTa,
    });
  }

  /// Admin: sửa loại rác (chỉ cần truyền các trường muốn đổi)
  static Future<void> suaLoaiRac(int id, Map<String, dynamic> duLieuMoi) async {
    await supabase.from('loai_rac').update(duLieuMoi).eq('id', id);
  }

  /// Admin: xóa loại rác
  /// LƯU Ý: nếu loại rác đang được lịch hẹn nào đó dùng, database sẽ CHẶN xóa
  /// (ràng buộc ON DELETE RESTRICT trong SQL) -> ta bắt lỗi và báo người dùng.
  static Future<void> xoaLoaiRac(int id) async {
    await supabase.from('loai_rac').delete().eq('id', id);
  }

  // ==========================================================================
  // PHẦN 2: LỊCH THU GOM (bảng lich_thu_gom) - trái tim của hệ thống
  // ==========================================================================

  /// UC04 - Khách đặt lịch thu gom mới
  /// Trả về id của lịch vừa tạo (phòng khi cần dùng tiếp)
  static Future<int> datLich({
    required int maLoaiRac,
    required String diaChi,
    required DateTime ngayHen,
    required String khungGio, // 'sang' hoặc 'chieu'
    required double khoiLuong,
    required num chiPhiDuKien,
    String? ghiChu,
    String? hinhAnhUrl, // link ảnh đã upload (có thể null)
  }) async {
    final userId = supabase.auth.currentUser!.id;

    // .select('id').single() = sau khi insert, lấy luôn id dòng mới
    final data = await supabase
        .from('lich_thu_gom')
        .insert({
          'ma_khach_hang': userId,
          'ma_loai_rac': maLoaiRac,
          'dia_chi_thu_gom': diaChi,
          // Đổi DateTime -> chuỗi 'YYYY-MM-DD' cho cột kiểu date
          'ngay_hen': ngayHen.toIso8601String().substring(0, 10),
          'khung_gio': khungGio,
          'khoi_luong_uoc_tinh': khoiLuong,
          'chi_phi_du_kien': chiPhiDuKien,
          'ghi_chu': ghiChu,
          'hinh_anh_url': hinhAnhUrl,
          // trang_thai tự động = 'cho_xac_nhan' (default trong SQL)
        })
        .select('id')
        .single();

    return data['id'] as int;
  }

  /// UC08 - Stream REALTIME danh sách lịch CỦA KHÁCH đang đăng nhập
  /// Dùng với StreamBuilder: admin vừa duyệt lịch là màn hình khách đổi ngay,
  /// KHÔNG cần bấm refresh. Đây chính là yêu cầu "update liên tục" của bạn.
  static Stream<List<Map<String, dynamic>>> streamLichCuaToi() {
    final userId = supabase.auth.currentUser!.id;
    return supabase
        .from('lich_thu_gom')
        .stream(primaryKey: ['id'])          // bắt buộc khai báo khóa chính
        .eq('ma_khach_hang', userId)          // chỉ lấy lịch của mình
        .order('ngay_dat', ascending: false); // mới nhất lên đầu
  }

  /// Stream REALTIME TẤT CẢ lịch (dành cho admin)
  static Stream<List<Map<String, dynamic>>> streamTatCaLich() {
    return supabase
        .from('lich_thu_gom')
        .stream(primaryKey: ['id'])
        .order('ngay_dat', ascending: false);
  }

  /// UC10 - Khách sửa lịch hẹn (chỉ khi còn 'cho_xac_nhan')
  static Future<void> suaLich(int id, Map<String, dynamic> duLieuMoi) async {
    await supabase.from('lich_thu_gom').update(duLieuMoi).eq('id', id);
  }

  /// UC10 - Hủy lịch: KHÔNG xóa dòng dữ liệu mà chỉ đổi trạng thái
  /// -> giữ lại lịch sử để làm báo cáo thống kê (đúng nghiệp vụ thực tế)
  static Future<void> huyLich(int id) async {
    await supabase
        .from('lich_thu_gom')
        .update({'trang_thai': 'da_huy'})
        .eq('id', id);
  }

  /// Admin duyệt / từ chối / hoàn tất lịch (UC "Xác nhận lịch hẹn")
  /// trangThaiMoi: 'da_xac_nhan' | 'hoan_tat' | 'da_huy'
  static Future<void> doiTrangThaiLich(int id, String trangThaiMoi) async {
    await supabase
        .from('lich_thu_gom')
        .update({'trang_thai': trangThaiMoi})
        .eq('id', id);
  }

  /// Lấy chi tiết 1 lịch KÈM thông tin liên quan.
  /// Cú pháp 'loai_rac(...)' = JOIN sang bảng khác qua khóa ngoại - Supabase
  /// tự hiểu nhờ ta đã khai báo REFERENCES trong SQL.
  static Future<Map<String, dynamic>> layChiTietLich(int id) async {
    return await supabase
        .from('lich_thu_gom')
        .select('*, loai_rac(ten_loai_rac, don_gia), '
            'nguoi_dung(ho_ten, so_dien_thoai)')
        .eq('id', id)
        .single();
  }

  // ==========================================================================
  // PHẦN 3: VẬT TƯ (bảng vat_tu) - UC11, UC12, UC13
  // ==========================================================================

  /// Lấy danh sách vật tư (dùng cho màn quản lý kho + form hoàn tất lịch)
  static Future<List<Map<String, dynamic>>> layDanhSachVatTu() async {
    return await supabase.from('vat_tu').select().order('id');
  }

  /// Admin: thêm vật tư mới vào kho
  static Future<void> themVatTu({
    required String ten,
    required String donViTinh,
    required int soLuongTon,
    required num donGia,
  }) async {
    await supabase.from('vat_tu').insert({
      'ten_vat_tu': ten,
      'don_vi_tinh': donViTinh,
      'so_luong_ton': soLuongTon,
      'don_gia': donGia,
    });
  }

  /// Sửa vật tư theo id - truyền vào Map các cột muốn đổi
  /// (VD: {'dinh_muc_su_dung': 2} chỉ đổi định mức, cột khác giữ nguyên)
  static Future<void> suaVatTu(int id, Map<String, dynamic> duLieuMoi) async {
    await supabase.from('vat_tu').update(duLieuMoi).eq('id', id);
  }

  /// UC12 (nhập kho: soLuong dương) & UC13 (xuất kho: soLuong âm)
  /// Cách làm đơn giản phù hợp bài tập: đọc tồn hiện tại -> cộng -> ghi lại.
  static Future<void> capNhatTonKho(int idVatTu, int soLuongThayDoi) async {
    // B1: đọc số tồn hiện tại
    final data = await supabase
        .from('vat_tu')
        .select('so_luong_ton')
        .eq('id', idVatTu)
        .single();

    final tonMoi = (data['so_luong_ton'] as int) + soLuongThayDoi;

    // B2: kiểm tra nghiệp vụ - không cho xuất quá số tồn
    if (tonMoi < 0) {
      throw Exception('Số lượng tồn không đủ để xuất kho!');
    }

    // B3: ghi số tồn mới
    await supabase
        .from('vat_tu')
        .update({'so_luong_ton': tonMoi})
        .eq('id', idVatTu);
  }

  /// Admin: xóa vật tư khỏi kho
  static Future<void> xoaVatTu(int id) async {
    await supabase.from('vat_tu').delete().eq('id', id);
  }

  // ==========================================================================
  // PHẦN 4: ĐÁNH GIÁ DỊCH VỤ (bảng danh_gia) - BM09
  // ==========================================================================

  /// Khách gửi đánh giá sau khi lịch hoàn tất
  static Future<void> guiDanhGia({
    required int maLich,
    required int soSao,
    String? nhanXet,
  }) async {
    await supabase.from('danh_gia').insert({
      'ma_lich': maLich,
      'ma_khach_hang': supabase.auth.currentUser!.id,
      'so_sao': soSao,
      'nhan_xet': nhanXet,
    });
  }

  /// Kiểm tra 1 lịch đã được đánh giá chưa (để ẩn/hiện nút đánh giá)
  static Future<bool> daDanhGia(int maLich) async {
    final data = await supabase
        .from('danh_gia')
        .select('id')
        .eq('ma_lich', maLich)
        .maybeSingle();
    return data != null;
  }

  // ==========================================================================
  // PHẦN 5: BÁO CÁO CHO ADMIN (BM07 doanh thu + BM10 thống kê loại rác)
  // ==========================================================================

  /// Báo cáo tổng hợp trong 1 tháng:
  ///  - Tổng doanh thu (chỉ tính lịch 'hoan_tat')
  ///  - Số lịch theo từng trạng thái
  ///  - Thống kê số lượt từng loại rác
  /// Ở trình độ năm 2, ta lấy dữ liệu về rồi TỰ TÍNH bằng Dart cho dễ hiểu
  /// (thay vì viết SQL GROUP BY phức tạp).
  static Future<Map<String, dynamic>> baoCaoThang(int nam, int thang) async {
    // Tính ngày đầu tháng và ngày đầu THÁNG SAU để lọc khoảng [đầu, cuối)
    final tuNgay = DateTime(nam, thang, 1);
    final denNgay = DateTime(nam, thang + 1, 1); // Dart tự xử lý tháng 12 -> năm sau

    // Lấy các lịch trong tháng, kèm tên loại rác (JOIN)
    final List<Map<String, dynamic>> dsLich = await supabase
        .from('lich_thu_gom')
        .select('trang_thai, chi_phi_du_kien, loai_rac(ten_loai_rac)')
        .gte('ngay_hen', tuNgay.toIso8601String().substring(0, 10)) // >= đầu tháng
        .lt('ngay_hen', denNgay.toIso8601String().substring(0, 10)); // < đầu tháng sau

    num tongDoanhThu = 0;
    final demTrangThai = <String, int>{}; // vd: {'hoan_tat': 5, 'da_huy': 2}
    final demLoaiRac = <String, int>{};  // vd: {'Rác sinh hoạt': 8}

    // Duyệt từng lịch để cộng dồn
    for (final lich in dsLich) {
      final trangThai = lich['trang_thai'] as String;

      // Đếm số lịch theo trạng thái
      demTrangThai[trangThai] = (demTrangThai[trangThai] ?? 0) + 1;

      // Chỉ lịch HOÀN TẤT mới tính doanh thu + thống kê loại rác
      if (trangThai == 'hoan_tat') {
        tongDoanhThu += (lich['chi_phi_du_kien'] as num? ?? 0);

        final tenLoai = lich['loai_rac']?['ten_loai_rac'] ?? 'Không rõ';
        demLoaiRac[tenLoai] = (demLoaiRac[tenLoai] ?? 0) + 1;
      }
    }

    return {
      'tong_doanh_thu': tongDoanhThu,
      'tong_so_lich': dsLich.length,
      'dem_trang_thai': demTrangThai,
      'dem_loai_rac': demLoaiRac,
    };
  }
}

// ============================================================================
// PHẦN BỔ SUNG: BÀI VIẾT / TIN TỨC (bảng bai_viet - update_01_bai_viet.sql)
// Đặt ngoài class dưới dạng extension? Không - để đơn giản cho năm 2, ta mở
// class thứ hai. Gọi bằng: BaiVietService.layDanhSachBaiViet()
// ============================================================================
class BaiVietService {
  /// Lấy tất cả bài viết, bài mới đăng hiện trước (ascending: false = giảm dần)
  static Future<List<Map<String, dynamic>>> layDanhSachBaiViet() async {
    return await supabase
        .from('bai_viet')
        .select()
        .order('ngay_dang', ascending: false);
  }

  /// Admin: đăng bài mới (hinhAnhUrl có thể null nếu không chọn ảnh)
  static Future<void> themBaiViet({
    required String tieuDe,
    required String tomTat,
    required String noiDung,
    String? hinhAnhUrl,
  }) async {
    await supabase.from('bai_viet').insert({
      'tieu_de': tieuDe,
      'tom_tat': tomTat,
      'noi_dung': noiDung,
      'hinh_anh_url': hinhAnhUrl,
    });
  }

  /// Admin: sửa bài viết theo id
  static Future<void> suaBaiViet(int id, Map<String, dynamic> duLieuMoi) async {
    await supabase.from('bai_viet').update(duLieuMoi).eq('id', id);
  }

  /// Admin: xóa bài viết theo id
  static Future<void> xoaBaiViet(int id) async {
    await supabase.from('bai_viet').delete().eq('id', id);
  }
}

// ============================================================================
// PHẦN BỔ SUNG: QUẢN LÝ NGƯỜI DÙNG (UC22 - dành cho admin)
// ============================================================================
class NguoiDungService {
  /// Admin: lấy toàn bộ người dùng, mới đăng ký hiện trước
  static Future<List<Map<String, dynamic>>> layTatCa() async {
    return await supabase
        .from('nguoi_dung')
        .select()
        .order('ngay_tao', ascending: false);
  }

  /// Admin: đổi vai trò ('khach_hang' <-> 'admin')
  static Future<void> doiVaiTro(String idNguoiDung, String vaiTroMoi) async {
    await supabase
        .from('nguoi_dung')
        .update({'vai_tro': vaiTroMoi}).eq('id', idNguoiDung);
  }

  /// Admin: khóa (true) hoặc mở khóa (false) tài khoản.
  /// Người bị khóa đăng nhập sẽ bị chặn ở màn hình thông báo (xem main.dart)
  static Future<void> datKhoa(String idNguoiDung, bool biKhoa) async {
    await supabase
        .from('nguoi_dung')
        .update({'bi_khoa': biKhoa}).eq('id', idNguoiDung);
  }
}

// ============================================================================
// PHẦN BỔ SUNG: HÓA ĐƠN (UC16/BM04) + trừ kho theo định mức (UC07)
// ============================================================================
class HoaDonService {
  /// NGHIỆP VỤ QUAN TRỌNG NHẤT: admin bấm "Hoàn tất" một lịch thu gom
  /// -> hàm này làm trọn gói 4 việc theo đúng quy trình trong báo cáo:
  ///   1. Kiểm tra kho còn đủ vật tư theo ĐỊNH MỨC không (thiếu -> báo lỗi, dừng)
  ///   2. Đổi trạng thái lịch sang 'hoan_tat'
  ///   3. Lập HÓA ĐƠN (tiền rác = chi phí dự kiến của lịch)
  ///   4. TRỪ KHO từng vật tư + ghi CHI TIẾT tiêu hao vào hóa đơn (snapshot giá)
  ///
  /// Ghi chú kỹ thuật: các bước chạy tuần tự từ app cho dễ hiểu với đồ án.
  /// Hệ thống thật sẽ gói tất cả vào 1 "transaction" trong database để đảm
  /// bảo hoặc-tất-cả-hoặc-không-gì (có thể nêu điểm này khi bảo vệ).
  ///
  /// [soLuongThucTe]: map {id vật tư: số lượng dùng thật} do admin duyệt lại
  /// trước khi hoàn tất (mặc định lấy theo định mức, nhưng lần thu gom nào
  /// dùng NHIỀU HƠN hay ÍT HƠN thì admin sửa số ngay trong hộp thoại).
  /// Không truyền -> dùng đúng định mức.
  static Future<void> hoanTatLichVaLapHoaDon(int maLich,
      {Map<int, int>? soLuongThucTe}) async {
    // --- Bước 0: đọc thông tin lịch ---
    final lich = await supabase
        .from('lich_thu_gom')
        .select('id, chi_phi_du_kien, trang_thai')
        .eq('id', maLich)
        .single();

    if (lich['trang_thai'] == 'hoan_tat') {
      throw 'Lịch này đã hoàn tất và có hóa đơn rồi.';
    }

    // --- Bước 1: xác định số lượng dùng cho TỪNG vật tư và kiểm tra tồn ---
    // Lấy TẤT CẢ vật tư (kể cả định mức 0) vì admin có thể thêm phát sinh
    final dsVatTuGoc = await supabase.from('vat_tu').select();

    // Danh sách (vật tư, số lượng dùng) sau khi áp số thực tế / định mức
    final dsSuDung = <(Map<String, dynamic>, int)>[];
    for (final vt in dsVatTuGoc) {
      // Ưu tiên số admin nhập; không có thì lấy định mức
      final soLuong =
          soLuongThucTe?[vt['id']] ?? (vt['dinh_muc_su_dung'] as int? ?? 0);
      if (soLuong <= 0) continue; // 0 = lần này không dùng vật tư đó

      if (vt['so_luong_ton'] < soLuong) {
        throw 'Kho không đủ "${vt['ten_vat_tu']}" '
            '(cần $soLuong, còn ${vt['so_luong_ton']}). '
            'Hãy nhập kho trước khi hoàn tất.';
      }
      dsSuDung.add((vt, soLuong));
    }

    // --- Bước 2: đổi trạng thái lịch ---
    await supabase
        .from('lich_thu_gom')
        .update({'trang_thai': 'hoan_tat'}).eq('id', maLich);

    // --- Bước 3: lập hóa đơn ---
    // Tổng tiền vật tư = cộng dồn (số lượng dùng x đơn giá) của từng vật tư
    num tongTienVatTu = 0;
    for (final (vt, soLuong) in dsSuDung) {
      tongTienVatTu += soLuong * (vt['don_gia'] as num);
    }

    final hoaDon = await supabase
        .from('hoa_don')
        .insert({
          'ma_lich': maLich,
          'tien_rac': lich['chi_phi_du_kien'],
          'tong_tien_vat_tu': tongTienVatTu,
        })
        .select()
        .single(); // .select().single() -> lấy lại dòng vừa chèn (cần id)

    // --- Bước 4: trừ kho + ghi chi tiết tiêu hao ---
    for (final (vt, soLuong) in dsSuDung) {
      // Trừ tồn kho
      await supabase.from('vat_tu').update({
        'so_luong_ton': (vt['so_luong_ton'] as int) - soLuong,
      }).eq('id', vt['id']);

      // Ghi dòng chi tiết (snapshot tên + đơn giá tại thời điểm lập)
      await supabase.from('hoa_don_vat_tu').insert({
        'ma_hoa_don': hoaDon['id'],
        'ma_vat_tu': vt['id'],
        'ten_vat_tu': vt['ten_vat_tu'],
        'don_vi_tinh': vt['don_vi_tinh'],
        'so_luong': soLuong,
        'don_gia': vt['don_gia'],
        'thanh_tien': soLuong * (vt['don_gia'] as num),
      });
    }
  }

  /// Admin: danh sách tất cả hóa đơn, kèm thông tin lịch + tên khách
  /// Cú pháp 'bang_con(cot)' = JOIN tự động của Supabase theo khóa ngoại
  static Future<List<Map<String, dynamic>>> layDanhSachHoaDon() async {
    return await supabase
        .from('hoa_don')
        .select('*, lich_thu_gom(ngay_hen, khoi_luong_uoc_tinh, dia_chi_thu_gom, '
            'loai_rac(ten_loai_rac), nguoi_dung(ho_ten, so_dien_thoai))')
        .order('ngay_lap', ascending: false);
  }

  /// Chi tiết vật tư tiêu hao của 1 hóa đơn
  static Future<List<Map<String, dynamic>>> layChiTietVatTu(int maHoaDon) async {
    return await supabase
        .from('hoa_don_vat_tu')
        .select()
        .eq('ma_hoa_don', maHoaDon);
  }

  /// Khách: lấy hóa đơn theo mã lịch (null nếu lịch chưa có hóa đơn)
  static Future<Map<String, dynamic>?> layHoaDonTheoLich(int maLich) async {
    return await supabase
        .from('hoa_don')
        .select('*, lich_thu_gom(loai_rac(ten_loai_rac), khoi_luong_uoc_tinh)')
        .eq('ma_lich', maLich)
        .maybeSingle();
  }
}

// ============================================================================
// PHẦN BỔ SUNG: THANH TOÁN (UC15 dạng demo - update_03_thanh_toan.sql)
// ============================================================================
class ThanhToanService {
  /// Khách chọn phương thức thanh toán cho 1 lịch.
  /// - 'tien_mat'      -> giữ trạng thái 'chua_thanh_toan', trả khi NV đến
  /// - 'chuyen_khoan'  -> sau khi khách quét QR và bấm xác nhận, chuyển
  ///                      sang 'khach_bao_da_chuyen' để admin biết mà kiểm tra
  static Future<void> khachChonThanhToan({
    required int maLich,
    required String phuongThuc,
    bool daChuyenKhoan = false,
  }) async {
    await supabase.from('lich_thu_gom').update({
      'phuong_thuc_tt': phuongThuc,
      // Toán tử ba ngôi: điều_kiện ? giá_trị_đúng : giá_trị_sai
      'trang_thai_tt':
          daChuyenKhoan ? 'khach_bao_da_chuyen' : 'chua_thanh_toan',
    }).eq('id', maLich);
    // Không cần "gửi thông báo" thủ công: bảng lich_thu_gom đã bật realtime,
    // màn hình admin đang mở sẽ TỰ thấy nhãn thanh toán đổi ngay lập tức.
  }

  /// Admin xác nhận ĐÃ NHẬN ĐƯỢC TIỀN (sau khi kiểm tra tài khoản/thu tiền mặt)
  static Future<void> adminXacNhanDaNhanTien(int maLich) async {
    await supabase
        .from('lich_thu_gom')
        .update({'trang_thai_tt': 'da_thanh_toan'}).eq('id', maLich);
  }
}
