// ============================================================================
// chuong_thong_bao.dart - CHUÔNG THÔNG BÁO ở header (khách + admin dùng chung)
// ----------------------------------------------------------------------------
// Icon chuông có badge đỏ đếm số thông báo CHƯA ĐỌC. Bấm vào mở bottom sheet
// liệt kê toàn bộ thông báo, realtime (StreamBuilder nghe ThongBaoService).
// ============================================================================

import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ChuongThongBao extends StatelessWidget {
  /// Gọi khi bấm 1 thông báo CÓ gắn lịch (ma_lich != null) - màn cha tự lo
  /// việc chuyển tab/mục tương ứng (khác nhau giữa màn khách và admin), vì
  /// widget dùng chung này không biết cấu trúc điều hướng riêng của mỗi bên.
  final void Function(int maLich)? onMoLich;
  const ChuongThongBao({super.key, this.onMoLich});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ThongBaoService.streamThongBao(),
      builder: (context, snapshot) {
        final soChuaDoc =
            (snapshot.data ?? []).where((t) => t['da_doc'] == false).length;

        return IconButton(
          tooltip: 'Thông báo',
          onPressed: () => _moDanhSach(context),
          icon: Badge(
            isLabelVisible: soChuaDoc > 0,
            label: Text(soChuaDoc > 9 ? '9+' : '$soChuaDoc'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }

  Future<void> _moDanhSach(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true, // cho phép sheet cao hơn nửa màn hình
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: _DanhSachThongBao(onMoLich: onMoLich),
      ),
    );
  }
}

/// Nội dung bottom sheet - StreamBuilder RIÊNG (không dùng lại snapshot lúc
/// bấm chuông) để danh sách vẫn realtime trong lúc sheet đang mở (ví dụ vừa
/// đánh dấu đã đọc thì nền đổi màu ngay, không cần đóng/mở lại sheet).
class _DanhSachThongBao extends StatelessWidget {
  final void Function(int maLich)? onMoLich;
  const _DanhSachThongBao({this.onMoLich});

  IconData _iconTheoLoai(String loai) {
    switch (loai) {
      case 'duyet':
        return Icons.check_circle_outline;
      case 'huy':
        return Icons.cancel_outlined;
      case 'thanh_toan':
        return Icons.payments_outlined;
      case 'tin_nhan':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  /// "5 phút trước" / "3 giờ trước" - thông báo cũ hơn 1 ngày thì hiện
  /// ngày giờ ngắn (dd/MM HH:mm) thay vì "24 giờ trước" mơ hồ.
  String _thoiGianTruoc(DateTime luc) {
    final khoangCach = DateTime.now().difference(luc);
    if (khoangCach.inMinutes < 1) return 'Vừa xong';
    if (khoangCach.inMinutes < 60) return '${khoangCach.inMinutes} phút trước';
    if (khoangCach.inHours < 24) return '${khoangCach.inHours} giờ trước';
    return '${luc.day.toString().padLeft(2, '0')}/'
        '${luc.month.toString().padLeft(2, '0')} '
        '${luc.hour.toString().padLeft(2, '0')}:'
        '${luc.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _bamThongBao(BuildContext context, Map<String, dynamic> tb) async {
    await ThongBaoService.danhDauDaDoc(tb['id']);
    if (!context.mounted) return;
    Navigator.pop(context); // đóng sheet trước khi (có thể) chuyển tab

    final maLich = tb['ma_lich'];
    if (maLich != null && onMoLich != null) {
      onMoLich!(maLich as int);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mauChuDao = Theme.of(context).colorScheme.primary;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ThongBaoService.streamThongBao(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final dsThongBao = snapshot.data!;
        final coChuaDoc = dsThongBao.any((t) => t['da_doc'] == false);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Thông báo',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton(
                    onPressed: coChuaDoc
                        ? () => ThongBaoService.danhDauTatCaDaDoc()
                        : null,
                    child: const Text('Đánh dấu tất cả đã đọc'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: dsThongBao.isEmpty
                  ? const Center(
                      child: Text('Chưa có thông báo.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      itemCount: dsThongBao.length,
                      itemBuilder: (context, i) {
                        final tb = dsThongBao[i];
                        final chuaDoc = tb['da_doc'] == false;
                        return Material(
                          // Material (không phải Container) để tô nền: Container
                          // vẽ đè lên trên làm ripple/ink của ListTile bị vô
                          // hình - Material tô nền NHƯNG vẫn là đúng lớp mà
                          // ListTile vẽ ripple lên, nên bấm vẫn thấy gợn sóng.
                          color: chuaDoc
                              ? mauChuDao.withOpacity(0.08)
                              : Colors.white,
                          child: ListTile(
                            leading:
                                Icon(_iconTheoLoai(tb['loai']), color: mauChuDao),
                            title: Text(tb['noi_dung']),
                            subtitle: Text(
                                _thoiGianTruoc(DateTime.parse(tb['ngay_tao']))),
                            onTap: () => _bamThongBao(context, tb),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
