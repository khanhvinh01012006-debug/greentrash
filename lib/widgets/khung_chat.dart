// ============================================================================
// khung_chat.dart - KHUNG CHAT khách hàng <-> admin, gắn theo 1 LỊCH cụ thể
// ----------------------------------------------------------------------------
// Dùng chung cho cả màn khách (lich_cua_toi_screen.dart) và màn admin
// (quan_ly_lich_screen.dart) - mở bằng hàm moKhungChat() bên dưới, tránh
// phải chép code bottom sheet 2 lần.
// ============================================================================

import 'package:flutter/material.dart';
import '../main.dart'; // để dùng biến `supabase`
import '../services/database_service.dart';

/// Mở khung chat trong bottom sheet - gọi hàm này từ cả màn khách lẫn admin.
Future<void> moKhungChat(BuildContext context, int maLich) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true, // cho phép sheet cao hơn nửa màn hình
    showDragHandle: true,
    builder: (ctx) => SizedBox(
      // Chiều cao cố định (không phải toàn màn) để vẫn thấy đây là 1 lớp nổi
      // lên trên, đóng lại quay về đúng danh sách lịch đang xem.
      height: MediaQuery.of(ctx).size.height * 0.75,
      child: KhungChat(maLich: maLich),
    ),
  );
}

class KhungChat extends StatefulWidget {
  final int maLich;
  const KhungChat({super.key, required this.maLich});

  @override
  State<KhungChat> createState() => _KhungChatState();
}

class _KhungChatState extends State<KhungChat> {
  final _noiDungCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _dangGui = false;

  @override
  void dispose() {
    _noiDungCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Cuộn xuống tin nhắn cuối cùng - gọi sau khi StreamBuilder build xong
  /// khung hình mới (addPostFrameCallback) để ListView đã có đủ chiều cao.
  void _cuonXuongDuoi() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _gui() async {
    final noiDung = _noiDungCtrl.text.trim();
    if (noiDung.isEmpty) return;

    _noiDungCtrl.clear(); // xóa ô nhập ngay, không đợi gửi xong
    setState(() => _dangGui = true);
    try {
      await ChatService.guiTinNhan(widget.maLich, noiDung);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser?.id;
    final mauChuDao = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Nhắn tin - Lịch #${widget.maLich}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const Divider(height: 1),

        // ---- Danh sách tin nhắn (realtime) ----
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: ChatService.streamTinNhan(widget.maLich),
            builder: (context, snapshot) {
              // TRẠNG THÁI 1: đang tải - chỉ hiện vòng xoay
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final dsTin = snapshot.data!;

              // TRẠNG THÁI 2: chưa có tin nào
              if (dsTin.isEmpty) {
                return const Center(
                  child: Text('Chưa có tin nhắn. Hãy bắt đầu trò chuyện.',
                      style: TextStyle(color: Colors.grey)),
                );
              }

              // TRẠNG THÁI 3: có tin - tự cuộn xuống cuối mỗi khi danh sách
              // đổi (tin mới của mình hoặc của người kia gửi tới)
              WidgetsBinding.instance.addPostFrameCallback((_) => _cuonXuongDuoi());

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: dsTin.length,
                itemBuilder: (context, i) {
                  final tin = dsTin[i];
                  final laCuaMinh = tin['nguoi_gui'] == userId;

                  return Align(
                    alignment:
                        laCuaMinh ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7),
                      decoration: BoxDecoration(
                        color: laCuaMinh ? mauChuDao : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        tin['noi_dung'],
                        style: TextStyle(
                            color: laCuaMinh ? Colors.white : Colors.black87),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ---- Ô nhập + nút gửi ----
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _noiDungCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Nhập tin nhắn...',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _gui(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _dangGui ? null : _gui,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
