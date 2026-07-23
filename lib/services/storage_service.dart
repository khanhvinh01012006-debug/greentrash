// ============================================================================
// storage_service.dart - UPLOAD HÌNH ẢNH lên Supabase Storage
// ----------------------------------------------------------------------------
// Luồng hoạt động:
//   1. Người dùng bấm nút chọn ảnh -> image_picker mở hộp thoại chọn file
//   2. Đọc ảnh thành mảng byte (Uint8List) - cách này chạy được CẢ WEB lẫn
//      điện thoại (trên web không có đường dẫn file nên không dùng File được)
//   3. Upload byte lên bucket 'hinh-anh-rac'
//   4. Lấy link công khai (public URL) -> lưu link này vào cột hinh_anh_url
//      của bảng lich_thu_gom -> khi cần hiện ảnh chỉ việc Image.network(link)
// ============================================================================

import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../config/supabase_config.dart';
import '../main.dart';

class StorageService {
  static final ImagePicker _picker = ImagePicker();

  /// Mở hộp thoại chọn ảnh. Trả về (bytes, tên file) hoặc null nếu người dùng
  /// bấm hủy không chọn gì.
  static Future<({Uint8List bytes, String tenFile})?> chonAnh() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery, // chọn từ thư viện/máy tính
      maxWidth: 1200,  // tự thu nhỏ ảnh để upload nhanh, đỡ tốn dung lượng
      imageQuality: 80, // nén 80% chất lượng
    );

    if (file == null) return null; // người dùng bấm hủy

    final bytes = await file.readAsBytes();
    return (bytes: bytes, tenFile: file.name);
  }

  /// Upload ảnh lên Storage, trả về LINK CÔNG KHAI của ảnh
  static Future<String> uploadAnh(Uint8List bytes, String tenFileGoc) async {
    // Đặt tên file duy nhất bằng thời gian hiện tại (mili giây) để 2 người
    // upload cùng lúc không bị trùng tên đè lên nhau
    final duoiFile = tenFileGoc.split('.').last; // lấy đuôi: jpg, png...
    final tenFile =
        '${supabase.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.$duoiFile';

    // Upload mảng byte lên bucket
    await supabase.storage
        .from(SupabaseConfig.bucketHinhAnh)
        .uploadBinary(tenFile, bytes);

    // Lấy link công khai để lưu vào database
    return supabase.storage
        .from(SupabaseConfig.bucketHinhAnh)
        .getPublicUrl(tenFile);
  }
}
