// ============================================================================
// customer_home_screen.dart - KHUNG CHÍNH phía khách hàng
// ----------------------------------------------------------------------------
// CHƯA đăng nhập (khách vãng lai): chỉ thấy Trang chủ - lướt xem thoải mái
// (giới thiệu, bảng giá, tin tức, liên hệ...), có thêm menu ngang phía trên
// giống các web dịch vụ (đưa chuột vào "DỊCH VỤ" sẽ xổ dropdown xuống).
// Bấm "Đặt lịch thu gom ngay" (hoặc "Đăng nhập" góc phải) -> mở màn Đăng
// nhập/Đăng ký.
//
// ĐÃ đăng nhập: hiện đủ 4 tab (thanh điều hướng dưới đáy):
//   Tab 1: Trang chủ  - giới thiệu dịch vụ + bảng giá + hướng dẫn phân loại
//   Tab 2: Đặt lịch   - đặt lịch thu gom mới (UC04)
//   Tab 3: Lịch của tôi - theo dõi realtime, hủy, đánh giá (UC08, UC10, BM09)
//   Tab 4: Tài khoản  - xem/sửa hồ sơ, đổi mật khẩu, đăng xuất (UC06)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../main.dart';
import '../auth/login_screen.dart';
import 'trang_chu_screen.dart';
import 'dat_lich_screen.dart';
import 'lich_cua_toi_screen.dart';
import 'tai_khoan_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  // Mốc bề rộng đổi layout: dưới mốc này dùng NavigationBar dưới đáy (kiểu
  // điện thoại), từ mốc trở lên đổi qua NavigationRail cột trái (kiểu web/
  // desktop) - xổ 1 thanh ngang dưới đáy trên màn hình rộng trông như app
  // di động bị phóng to, không hợp.
  static const double _mocManHinhRong = 900;

  // Dữ liệu 4 tab (icon + nhãn) - khai 1 LẦN ở đây rồi dùng chung để tạo
  // cả NavigationDestination (NavigationBar) lẫn NavigationRailDestination
  // (NavigationRail), tránh chép 2 bộ icon/nhãn dễ lệch nhau khi sửa sau này.
  static const List<(IconData, String)> _diemDieuHuong = [
    (Icons.home_outlined, 'Trang chủ'),
    (Icons.add_circle_outline, 'Đặt lịch'),
    (Icons.list_alt, 'Lịch của tôi'),
    (Icons.person_outline, 'Tài khoản'),
  ];

  int _tabDangChon = 0; // vị trí tab đang mở (0..3) - chỉ dùng khi đã đăng nhập

  // Cuộn + "cột mốc" của Trang chủ - khai báo 1 LẦN ở đây (không phải trong
  // build()) vì GlobalKey/ScrollController phải giữ nguyên danh tính suốt
  // vòng đời màn hình thì Scrollable.ensureVisible mới tìm đúng vị trí.
  final _scrollTrangChu = ScrollController();
  final _keyGioiThieu = GlobalKey();
  final _keyQuyTrinh = GlobalKey();
  final _keyBangGia = GlobalKey();
  final _keyTinTuc = GlobalKey();
  final _keyHuongDan = GlobalKey();
  final _keyLienHe = GlobalKey();

  bool get _daDangNhap => supabase.auth.currentUser != null;

  @override
  void dispose() {
    _scrollTrangChu.dispose();
    super.dispose();
  }

  /// Bấm "Đặt lịch thu gom ngay" / "Đăng nhập" / mục "Đặt lịch ngay" trong
  /// dropdown: đã đăng nhập -> nhảy thẳng qua tab Đặt lịch; chưa đăng nhập
  /// -> mở màn Đăng nhập/Đăng ký trước, đăng nhập xong quay lại xem tiếp.
  Future<void> _batDauDatLich() async {
    if (_daDangNhap) {
      setState(() => _tabDangChon = 1);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    // Khách bấm nút back hủy đăng nhập (không đăng nhập) vẫn quay lại được
    // Trang chủ bình thường - dòng này chỉ để chắc chắn giao diện cập nhật.
    if (mounted) setState(() {});
  }

  /// Cuộn Trang chủ lên đầu (mục "TRANG CHỦ" trong menu ngang)
  void _cuonLenDau() {
    setState(() => _tabDangChon = 0);
    _scrollTrangChu.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  /// Cuộn Trang chủ tới đúng khối tương ứng với 1 mục trong menu ngang.
  /// KHÔNG dùng Scrollable.ensureVisible trực tiếp vì mục bấm thường đi kèm
  /// việc đóng dropdown (menu ngang co lại -> vùng cuộn của Trang chủ đổi
  /// kích thước) - nếu đo vị trí ngay khung hình kế tiếp, có lúc layout web
  /// chưa ổn định hẳn, đo sai rồi tự "giật" sửa lại ở khung hình sau, nhìn
  /// như nhảy xuống rồi giật lên lại. Ở đây mình:
  ///   1. Đợi 2 khung hình (không phải 1) để chắc chắn dropdown đã đóng và
  ///      layout đã ổn định hoàn toàn.
  ///   2. Tự tính toạ độ đích rồi CLAMP trong [0, maxScrollExtent] trước khi
  ///      animate - không bao giờ vượt mép cuộn nên không bị bật lại.
  void _cuonToi(GlobalKey key) {
    setState(() => _tabDangChon = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollTrangChu.hasClients) return;
        final renderObject = key.currentContext?.findRenderObject();
        if (renderObject == null) return;

        final viewport = RenderAbstractViewport.of(renderObject);
        final toaDo = viewport.getOffsetToReveal(renderObject, 0.0).offset;
        final gioiHan = _scrollTrangChu.position.maxScrollExtent;
        final toaDoHopLe = toaDo.clamp(0.0, gioiHan);

        _scrollTrangChu.animateTo(toaDoHopLe,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final trangChu = TrangChuScreen(
      onDatLichNgay: _batDauDatLich,
      scrollController: _scrollTrangChu,
      keyGioiThieu: _keyGioiThieu,
      keyQuyTrinh: _keyQuyTrinh,
      keyBangGia: _keyBangGia,
      keyTinTuc: _keyTinTuc,
      keyHuongDan: _keyHuongDan,
      keyLienHe: _keyLienHe,
    );

    // Menu ngang phía trên - đưa chuột vào (web) hoặc bấm (điện thoại) vào
    // các mục có mũi tên sẽ xổ dropdown xuống, giống các web dịch vụ tham
    // khảo. TRANG CHỦ và LIÊN HỆ không có mục con thật (chỉ có 1 đích đến)
    // nên để bấm thẳng, giống cách trang tham khảo cũng xử lý 2 mục này.
    final menuNgang = _ThanhMenuNgang(cacMuc: [
      _MucMenu('TRANG CHỦ', onTap: _cuonLenDau),
      _MucMenu('GIỚI THIỆU', mucCon: [
        ('Về GreenTrash', () => _cuonToi(_keyGioiThieu)),
        ('Quy trình hoạt động', () => _cuonToi(_keyQuyTrinh)),
      ]),
      _MucMenu('DỊCH VỤ', mucCon: [
        ('Bảng giá thu gom', () => _cuonToi(_keyBangGia)),
        ('Đặt lịch ngay', _batDauDatLich),
      ]),
      _MucMenu('TIN TỨC', mucCon: [
        ('Tin tức & mẹo sống xanh', () => _cuonToi(_keyTinTuc)),
        ('Hướng dẫn phân loại rác', () => _cuonToi(_keyHuongDan)),
      ]),
      _MucMenu('LIÊN HỆ', onTap: () => _cuonToi(_keyLienHe)),
    ]);

    // Tiêu đề AppBar: icon + tên app + khẩu hiệu nhỏ chạy chữ bên dưới -
    // trước đây chỉ có icon+chữ trông khá trống trải trên nền xanh to
    final tieuDeApp = Row(
      children: [
        const Icon(Icons.eco, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('GreenTrash',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
              SizedBox(height: 2),
              _KhauHieuChay(),
            ],
          ),
        ),
      ],
    );

    // ==========================================================================
    // KHÁCH VÃNG LAI (chưa đăng nhập): chỉ thấy Trang chủ, chưa thấy Đặt lịch/
    // Lịch của tôi/Tài khoản - đúng như luồng "xem trước, ưng thì đăng ký"
    // ==========================================================================
    if (!_daDangNhap) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 68,
          title: tieuDeApp,
          actions: [
            TextButton.icon(
              onPressed: _batDauDatLich,
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Đăng nhập',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _NenTrangTri(
          // stretch: menu ngang bên dưới PHẢI tràn hết bề rộng màn hình,
          // không thì Column mặc định canh giữa sẽ co nó lại theo bề rộng
          // nội dung (nhìn như 1 khung nhỏ lơ lửng, không đẹp)
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              menuNgang,
              Expanded(child: trangChu),
            ],
          ),
        ),
      );
    }

    // ==========================================================================
    // ĐÃ ĐĂNG NHẬP: đủ 4 tab như trước
    // ==========================================================================
    final cacTab = [
      trangChu,
      const DatLichScreen(),
      const LichCuaToiScreen(),
      const TaiKhoanScreen(),
    ];

    // Nội dung chính (menu ngang + IndexedStack 4 tab) - khai báo 1 LẦN duy
    // nhất ở đây rồi dùng chung cho cả layout hẹp (mobile) lẫn layout rộng
    // (desktop) bên dưới. Nhờ vậy IndexedStack luôn là CÙNG MỘT cây widget,
    // không bị build thành 2 bản riêng biệt (build 2 bản = 2 State khác
    // nhau -> mất trạng thái tab, đúng cái phải tránh).
    final noiDungChinh = _NenTrangTri(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Menu ngang CHỈ có ý nghĩa ở tab Trang chủ (nhảy tới các khối
          // trên trang đó) - các tab khác không có gì để cuộn tới nên ẩn
          // đi, tránh hiện thừa một thanh menu vô dụng ở trên đầu
          if (_tabDangChon == 0) menuNgang,
          Expanded(
            child: IndexedStack(index: _tabDangChon, children: cacTab),
          ),
        ],
      ),
    );

    // LayoutBuilder: đo bề rộng thật sự có để vẽ, từ đó chọn kiểu điều hướng
    // phù hợp - dưới 900px giữ nguyên NavigationBar dưới đáy như cũ, từ
    // 900px trở lên đổi qua NavigationRail cột trái.
    return LayoutBuilder(builder: (context, constraints) {
      final manHinhRong = constraints.maxWidth >= _mocManHinhRong;

      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 68,
          title: tieuDeApp,
          actions: [
            IconButton(
              tooltip: 'Tài khoản',
              icon: const Icon(Icons.account_circle_outlined,
                  color: Colors.white),
              onPressed: () => setState(() => _tabDangChon = 3),
            ),
            const SizedBox(width: 8),
          ],
        ),

        // Màn hình rộng: thêm NavigationRail cột trái, nội dung chính co
        // giãn (Expanded) chiếm phần còn lại. Màn hình hẹp: nội dung chính
        // chiếm trọn bề ngang như trước.
        body: manHinhRong
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _tabDangChon,
                    onDestinationSelected: (i) =>
                        setState(() => _tabDangChon = i),
                    labelType: NavigationRailLabelType.all,
                    destinations: _diemDieuHuong
                        .map((d) => NavigationRailDestination(
                            icon: Icon(d.$1), label: Text(d.$2)))
                        .toList(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: noiDungChinh),
                ],
              )
            : noiDungChinh,

        // Thanh điều hướng dưới đáy - CHỈ hiện ở màn hình hẹp, màn hình rộng
        // đã có NavigationRail thay thế nên bỏ (null).
        bottomNavigationBar: manHinhRong
            ? null
            : NavigationBar(
                selectedIndex: _tabDangChon,
                onDestinationSelected: (i) => setState(() => _tabDangChon = i),
                destinations: _diemDieuHuong
                    .map((d) =>
                        NavigationDestination(icon: Icon(d.$1), label: d.$2))
                    .toList(),
              ),
      );
    });
  }
}

// ============================================================================
// _KhauHieuChay: khẩu hiệu nhỏ dưới tên "GreenTrash" trên AppBar, cứ vài
// giây tự đổi sang câu khác (hiệu ứng mờ dần - AnimatedSwitcher) để phần
// đầu trang đỡ trống trải, giống dòng chữ chạy ở header các web dịch vụ.
// ============================================================================
class _KhauHieuChay extends StatefulWidget {
  const _KhauHieuChay();

  @override
  State<_KhauHieuChay> createState() => _KhauHieuChayState();
}

class _KhauHieuChayState extends State<_KhauHieuChay> {
  static const _cauKhauHieu = [
    '🌱 Phân loại rác để có một môi trường sạch - đẹp hơn',
    '🚛 Thu gom rác tận nhà - nhanh chóng, đúng hẹn',
    '♻️ Rác tái chế cũng là tài nguyên - đừng bỏ phí',
  ];

  int _chiSo = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _chiSo = (_chiSo + 1) % _cauKhauHieu.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      // Mặc định AnimatedSwitcher xếp CHỒNG cả câu cũ (đang mờ đi) và câu
      // mới (đang hiện ra) lên nhau trong lúc chuyển - vì 3 câu khẩu hiệu
      // dài ngắn khác nhau, chồng cả 2 câu full lên nhau nhìn như chữ đè
      // chữ, khó đọc. layoutBuilder này chỉ giữ câu MỚI, bỏ câu cũ ra khỏi
      // phần xếp chồng -> vẫn mờ dần khi xuất hiện nhưng không đè chữ.
      layoutBuilder: (currentChild, previousChildren) =>
          currentChild ?? const SizedBox.shrink(),
      child: Text(
        _cauKhauHieu[_chiSo],
        key: ValueKey(_chiSo),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ============================================================================
// _MucMenu: dữ liệu 1 mục trong menu ngang.
//   - Không có mucCon -> bấm/hover là chạy thẳng onTap (vd: cuộn tới 1 khối)
//   - Có mucCon -> hover (web) hoặc bấm (điện thoại) sẽ xổ dropdown liệt kê
//     các mục con, bấm vào mục con mới thực sự điều hướng
// ============================================================================
class _MucMenu {
  final String ten;
  final VoidCallback? onTap;
  final List<(String, VoidCallback)>? mucCon;
  const _MucMenu(this.ten, {this.onTap, this.mucCon});
}

// ============================================================================
// _ThanhMenuNgang: menu ngang, dropdown XỔ NGAY DƯỚI từng mục (không phải 1
// khung dùng chung tràn hết bề rộng như trước).
// Cách hoạt động:
//   - Mỗi mục CÓ dropdown được bọc trong CompositedTransformTarget kèm 1
//     LayerLink riêng - đánh dấu "tọa độ neo" của đúng mục đó trên màn hình.
//   - OverlayPortal (1 cái dùng chung, vì chỉ 1 dropdown mở tại 1 thời điểm)
//     vẽ khung dropdown vào lớp Overlay của app, rồi dùng
//     CompositedTransformFollower bám theo đúng LayerLink của mục đang mở
//     -> dropdown luôn xổ thẳng xuống ngay dưới mục đó, không lệch xa.
// Desktop/web: MouseRegion.onEnter mở dropdown ngay khi rê chuột vào.
// Điện thoại (không có chuột): bấm vào mục cũng mở/đóng được y hệt.
// ============================================================================
class _ThanhMenuNgang extends StatefulWidget {
  final List<_MucMenu> cacMuc;
  const _ThanhMenuNgang({required this.cacMuc});

  @override
  State<_ThanhMenuNgang> createState() => _ThanhMenuNgangState();
}

class _ThanhMenuNgangState extends State<_ThanhMenuNgang> {
  static const _xanh = Color(0xFF2E7D32);
  static const _xanhNhat = Color(0xFFE8F5E9);

  String? _mucDangMo; // tên mục đang xổ dropdown xuống (null = không có)
  final _overlayController = OverlayPortalController();

  // Mỗi mục có dropdown cần 1 LayerLink riêng để neo đúng vị trí của nó
  final Map<String, LayerLink> _lienKet = {};
  LayerLink _layerLinkCua(String ten) =>
      _lienKet.putIfAbsent(ten, () => LayerLink());

  // Trì hoãn việc ĐÓNG dropdown: giữa nút "DỊCH VỤ" và khung dropdown có 1
  // khoảng hở nhỏ (offset 4px) - khi rê chuột từ nút xuống khung, chuột đi
  // qua khoảng hở đó 1 khắc, onExit của nút kích hoạt ngay lập tức khiến
  // dropdown biến mất TRƯỚC khi chuột kịp chạm vào khung -> nhìn như "không
  // bấm được". Đợi 150ms trước khi thực sự đóng; nếu chuột kịp vào lại
  // (nút hoặc khung dropdown) trong lúc đó, _mo() sẽ hủy hẹn đóng này.
  Timer? _henDong;

  void _mo(String ten) {
    _henDong?.cancel();
    setState(() => _mucDangMo = ten);
    _overlayController.show();
  }

  // Đóng NGAY - dùng khi người dùng đã bấm chọn xong (tap vào mục con, tap
  // ra ngoài...), không cần chờ gì nữa
  void _dong() {
    _henDong?.cancel();
    setState(() => _mucDangMo = null);
    _overlayController.hide();
  }

  // Đóng TRỄ 150ms - dùng cho onExit (rê chuột ra khỏi nút/khung dropdown),
  // để chuột kịp đi qua khoảng hở giữa 2 vùng mà không bị đóng hụt
  void _dongTre() {
    _henDong?.cancel();
    _henDong = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _mucDangMo = null);
      _overlayController.hide();
    });
  }

  @override
  void dispose() {
    _henDong?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tìm mục đang mở (nếu có) để vẽ dropdown tương ứng
    _MucMenu? mucDangMo;
    for (final muc in widget.cacMuc) {
      if (muc.ten == _mucDangMo) {
        mucDangMo = muc;
        break;
      }
    }

    return Material(
      color: Colors.white,
      elevation: 1,
      child: OverlayPortal(
        controller: _overlayController,
        // Vẽ khung dropdown nổi, bám theo đúng mục đang mở
        overlayChildBuilder: (context) {
          if (mucDangMo == null || mucDangMo.mucCon == null) {
            return const SizedBox.shrink();
          }
          final mucCon = mucDangMo.mucCon!;
          return CompositedTransformFollower(
            link: _layerLinkCua(mucDangMo.ten),
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            // Bọc lại Align (cần thiết): CompositedTransformFollower vẫn có
            // thể ép chiều cao/rộng của child theo cả vùng overlay còn lại
            // nếu không có gì "nới lỏng" ràng buộc - đó chính là lý do khối
            // dropdown bị giãn to full màn hình (thấy trong ảnh bạn gửi),
            // và một khối Material to như vậy sẽ "nuốt" luôn thao tác bấm ở
            // vùng đó (kể cả khi tưởng đang bấm banner bên dưới) - ĐÂY mới
            // là nguyên nhân thật của lỗi "vướng banner" trước đó, không
            // phải do Align. Align nới lỏng ràng buộc CHO CHILD nhưng bản
            // thân Align không chặn click ở vùng trống xung quanh.
            // Thêm ConstrainedBox giới hạn bề rộng tối đa để chắc chắn dropdown
            // không bao giờ phình to bất thường.
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: MouseRegion(
                  onEnter: (_) => _mo(mucDangMo!.ten),
                  onExit: (_) => _dongTre(),
                  child: Material(
                    color: _xanhNhat,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: mucCon.map((mc) {
                        return InkWell(
                          onTap: () {
                            _dong();
                            mc.$2();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Text(mc.$1,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: widget.cacMuc.map((muc) {
              final coDropdown = muc.mucCon != null && muc.mucCon!.isNotEmpty;
              final dangMo = muc.ten == _mucDangMo;

              Widget mucNay = MouseRegion(
                onEnter: coDropdown ? (_) => _mo(muc.ten) : null,
                onExit: coDropdown ? (_) => _dongTre() : null,
                child: InkWell(
                  onTap: () {
                    if (coDropdown) {
                      dangMo ? _dong() : _mo(muc.ten);
                    } else {
                      _dong();
                      muc.onTap?.call();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          muc.ten,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: dangMo ? _xanh : Colors.black87,
                          ),
                        ),
                        if (coDropdown) ...[
                          const SizedBox(width: 4),
                          Icon(
                            dangMo
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18,
                            color: dangMo ? _xanh : Colors.black54,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );

              // Chỉ mục CÓ dropdown mới cần "cắm cọc" LayerLink để dropdown
              // của riêng nó bám đúng vị trí
              if (coDropdown) {
                mucNay = CompositedTransformTarget(
                  link: _layerLinkCua(muc.ten),
                  child: mucNay,
                );
              }
              return mucNay;
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _NenTrangTri: nền chuyển màu + các icon môi trường MỜ rải 2 bên màn hình.
// Mục đích: trên web, nội dung được gom vào giữa (tối đa 1000px) nên 2 bên
// hay bị trống - widget này lấp khoảng trống bằng họa tiết nhẹ nhàng.
// Cách hoạt động: Stack xếp chồng 3 lớp:
//   Lớp 1 (dưới cùng): Container nền gradient xanh nhạt -> trắng
//   Lớp 2: các Positioned đặt icon ở tọa độ cố định, Opacity 0.05 (rất mờ)
//   Lớp 3 (trên cùng): nội dung thật của app (child)
// ============================================================================
class _NenTrangTri extends StatelessWidget {
  final Widget child;
  const _NenTrangTri({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Lớp 1: nền chuyển màu
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE8F5E9), Color(0xFFFAFDF7)],
              ),
            ),
          ),
        ),

        // Lớp 2: họa tiết icon mờ - Positioned đặt theo 4 góc/cạnh
        const Positioned(
          left: 30,
          top: 120,
          child: Opacity(
              opacity: 0.05,
              child:
                  Icon(Icons.recycling, size: 160, color: Color(0xFF1B5E20))),
        ),
        const Positioned(
          left: 60,
          bottom: 80,
          child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.eco, size: 120, color: Color(0xFF1B5E20))),
        ),
        const Positioned(
          right: 30,
          top: 220,
          child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.local_shipping_outlined,
                  size: 140, color: Color(0xFF1B5E20))),
        ),
        const Positioned(
          right: 70,
          bottom: 140,
          child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.delete_outline,
                  size: 110, color: Color(0xFF1B5E20))),
        ),

        // Lớp 3: nội dung app đè lên trên
        Positioned.fill(child: child),
      ],
    );
  }
}
