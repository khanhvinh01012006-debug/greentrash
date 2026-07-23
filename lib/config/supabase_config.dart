// ============================================================================
// supabase_config.dart - NƠI DUY NHẤT chứa thông tin kết nối Supabase
// ----------------------------------------------------------------------------
// CÁCH LẤY 2 GIÁ TRỊ NÀY:
//   1. Vào https://supabase.com -> mở project của bạn
//   2. Bấm biểu tượng bánh răng (Project Settings) -> mục "API"
//   3. Copy "Project URL" dán vào supabaseUrl
//   4. Copy "anon public" key dán vào supabaseAnonKey
//
// LƯU Ý: anon key là key CÔNG KHAI, được phép nằm trong app. Dữ liệu vẫn an
// toàn vì ta đã bật Row Level Security (RLS) trong file schema.sql.
// ============================================================================

class SupabaseConfig {
  // TODO: Thay bằng Project URL của bạn
  static const String supabaseUrl = 'https://bruxrqjqcunhmedhyijv.supabase.co';

  // TODO: Thay bằng anon public key của bạn
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJydXhycWpxY3VuaG1lZGh5aWp2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2MzYxMDcsImV4cCI6MjEwMDIxMjEwN30.EAIq_zFmAtQ3utB7qGNRhwxp1fVmA9MnRUYsU17UCoc';

  // Tên bucket lưu ảnh (phải tạo trong Supabase Storage, bật Public)
  static const String bucketHinhAnh = 'hinh-anh-rac';
}
