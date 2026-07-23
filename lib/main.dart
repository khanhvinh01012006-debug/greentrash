// ============================================================================
// main.dart - ĐIỂM KHỞI ĐẦU của ứng dụng GreenTrash
// ----------------------------------------------------------------------------
// Nhiệm vụ của file này:
//   1. Khởi tạo kết nối Supabase (phải làm TRƯỚC khi chạy app)
//   2. Cài đặt theme màu xanh lá cho toàn app
//   3. Điều hướng: chưa đăng nhập -> màn hình Login
//                  đã đăng nhập   -> kiểm tra vai trò -> Trang Khách / Trang Admin
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

Future<void> main() async {
  // Bắt buộc gọi dòng này khi main() có code bất đồng bộ (await) trước runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Đường dẫn web sạch: hiện "/admin" thay vì "/#/admin" trên thanh địa chỉ
  usePathUrlStrategy();

  // Khởi tạo Supabase với URL + key trong file config
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const GreenTrashApp());
}

/// Biến tắt để gọi Supabase ở mọi nơi trong app: chỉ cần viết `supabase.`
final supabase = Supabase.instance.client;

class GreenTrashApp extends StatelessWidget {
  const GreenTrashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GreenTrash',
      debugShowCheckedModeBanner: false, // Ẩn chữ DEBUG góc phải

      // Theme xanh lá - chủ đề môi trường
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Xanh lá đậm
        ),
        useMaterial3: true,
        // AppBar mặc định của Material 3 nền màu rất nhạt (gần trắng) - nếu
        // không khai báo riêng thì chữ/icon TRẮNG đặt lên trên (như nút
        // "Đăng nhập") sẽ bị chìm mất, gần như vô hình. Cố định nền xanh đậm
        // + chữ trắng cho MỌI AppBar trong app để luôn tương phản rõ.
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
        ),
        // Style chung cho các ô nhập liệu trong toàn app
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),

      // Khai báo đường dẫn: "/" và "/admin" đều chạy CongDieuHuong -
      // widget này tự đồng bộ lại URL cho đúng vai trò thật (xem bên dưới),
      // nên gõ thẳng .../admin mà không phải admin cũng không "lách" được.
      initialRoute: '/',
      routes: {
        '/': (context) => const CongDieuHuong(),
        '/admin': (context) => const CongDieuHuong(),
      },
      // Gõ nhầm đường dẫn không tồn tại -> quay về trang chủ thay vì lỗi
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const CongDieuHuong()),
    );
  }
}

// ============================================================================
// CongDieuHuong - Widget quyết định hiển thị màn hình nào
// ----------------------------------------------------------------------------
// Dùng StreamBuilder lắng nghe trạng thái đăng nhập của Supabase:
//   - Mỗi khi người dùng đăng nhập / đăng xuất, stream phát tín hiệu
//     -> widget này tự build lại -> chuyển màn hình tự động.
// ============================================================================
class CongDieuHuong extends StatefulWidget {
  const CongDieuHuong({super.key});

  @override
  State<CongDieuHuong> createState() => _CongDieuHuongState();
}

class _CongDieuHuongState extends State<CongDieuHuong> {
  // "Bộ nhớ đệm" vai trò: chỉ hỏi database 1 LẦN cho mỗi phiên đăng nhập.
  // Nếu không có 2 biến này, mỗi lần app build lại sẽ hỏi database lại
  // -> màn hình chờ xoay lâu không cần thiết.
  Future<String>? _vaiTroFuture; // kết quả đang chờ / đã có
  String? _userIdDaHoi; // id người dùng đã hỏi (đổi người -> hỏi lại)

  /// Đọc vai trò (khach_hang / admin) của người đang đăng nhập từ bảng nguoi_dung
  /// Trả về thêm giá trị đặc biệt 'bi_khoa' nếu tài khoản đã bị admin khóa
  Future<String> _layVaiTro() async {
    final userId = supabase.auth.currentUser!.id;

    // .maybeSingle() = lấy 1 dòng, nếu không có trả về null (không văng lỗi)
    final data = await supabase
        .from('nguoi_dung')
        .select('vai_tro, bi_khoa')
        .eq('id', userId)
        .maybeSingle();

    // Tài khoản bị khóa -> trả mã riêng để hiện màn hình chặn
    if (data?['bi_khoa'] == true) return 'bi_khoa';

    // Nếu vì lý do nào đó chưa có hồ sơ thì coi như khách hàng
    return data?['vai_tro'] ?? 'khach_hang';
  }

  @override
  Widget build(BuildContext context) {
    // Lồng 2 tầng builder vì 2 việc có tốc độ khác nhau: đăng nhập/đăng xuất
    // là sự kiện tức thời (StreamBuilder bắt ngay), còn hỏi VAI TRÒ phải gọi
    // thêm 1 query async tới database (FutureBuilder chờ kết quả) - không
    // gộp làm 1 được vì FutureBuilder cần biết ĐÃ đăng nhập ai rồi mới hỏi.
    return StreamBuilder<AuthState>(
      // Stream trạng thái đăng nhập do Supabase cung cấp sẵn
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        // CHƯA đăng nhập -> hiện màn hình Login, đồng thời xóa cache vai trò
        // CHƯA đăng nhập -> vẫn cho xem Trang chủ (khách vãng lai), chỉ khi
        // bấm "Tạo đơn thu gom" hoặc vào Lịch/Tài khoản mới bị dẫn sang
        // LoginScreen (xem customer_home_screen.dart)
        if (session == null) {
          _vaiTroFuture = null;
          _userIdDaHoi = null;
          _dongBoDuongDan(context, '/');
          return const CustomerHomeScreen();
        }

        // ĐÃ đăng nhập -> chỉ hỏi vai trò nếu CHƯA hỏi cho người này
        if (_vaiTroFuture == null || _userIdDaHoi != session.user.id) {
          _userIdDaHoi = session.user.id;
          _vaiTroFuture = _layVaiTro();
        }

        return FutureBuilder<String>(
          future: _vaiTroFuture,
          builder: (context, roleSnapshot) {
            // BỊ LỖI khi hỏi database -> hiện lỗi ra màn hình (không xoay mãi)
            // Ví dụ lỗi hay gặp: chưa chạy schema.sql nên chưa có bảng nguoi_dung
            if (roleSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 56, color: Colors.red),
                        const SizedBox(height: 12),
                        const Text('Không đọc được dữ liệu tài khoản',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        // In nguyên văn lỗi để biết đường sửa
                        SelectableText('${roleSnapshot.error}',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton(
                              // Xóa cache rồi setState -> hỏi database lại
                              onPressed: () => setState(() {
                                _vaiTroFuture = null;
                              }),
                              child: const Text('Thử lại'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () => supabase.auth.signOut(),
                              child: const Text('Đăng xuất'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Đang tải vai trò -> hiện vòng xoay chờ
            if (!roleSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Chia đường theo vai trò
            // TÀI KHOẢN BỊ KHÓA -> chặn lại, chỉ cho đăng xuất
            if (roleSnapshot.data == 'bi_khoa') {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_person_outlined,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text('Tài khoản của bạn đã bị khóa',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'Vui lòng liên hệ quản trị viên để được hỗ trợ mở khóa.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => supabase.auth.signOut(),
                          child: const Text('Đăng xuất'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (roleSnapshot.data == 'admin') {
              _dongBoDuongDan(context, '/admin');
              return const AdminHomeScreen();
            }
            _dongBoDuongDan(context, '/');
            return const CustomerHomeScreen();
          },
        );
      },
    );
  }

  /// Cập nhật thanh địa chỉ trình duyệt cho KHỚP với vai trò thật vừa xác
  /// nhận từ database (không phải chỉ dựa vào chữ gõ trên URL).
  /// Ví dụ: admin đăng nhập xong -> URL tự đổi từ "/" thành "/admin".
  void _dongBoDuongDan(BuildContext context, String duongDanMongMuon) {
    final duongDanHienTai = ModalRoute.of(context)?.settings.name;
    if (duongDanHienTai == duongDanMongMuon) return;
    // Đợi build xong mới điều hướng - không được gọi Navigator giữa lúc build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(duongDanMongMuon);
    });
  }
}
