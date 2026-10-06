import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/admin_controller.dart';

/// Bir öğrencinin grup üyeliklerini yönetir.
///
/// Üyelik değişikliği `setGroupMembership` çağrısıyla sunucuya gider;
/// `users/{uid}.groupIds` aynası da aynı transaction'da güncellenir.
class StudentGroupsScreen extends StatefulWidget {
  const StudentGroupsScreen({super.key, required this.student});

  final AppUser student;

  static Future<void> open(BuildContext context, AppUser student) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StudentGroupsScreen(student: student)),
      );

  @override
  State<StudentGroupsScreen> createState() => _StudentGroupsScreenState();
}

class _StudentGroupsScreenState extends State<StudentGroupsScreen> {
  late AppUser _student = widget.student;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();

    return Scaffold(
      appBar: AppBar(title: Text(_student.fullName.isEmpty ? _student.email : _student.fullName)),
      body: Column(
        children: [
          StreamBuilder<List<AppGroup>>(
            stream: admin.watchGroups(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const AppError(message: 'Gruplar alınamadı.');
              if (!snapshot.hasData) return const AppLoading();

              final groups = snapshot.data ?? const <AppGroup>[];
              if (groups.isEmpty) {
                return const AppEmpty(
                  title: 'Grup yok',
                  description: 'Önce grup oluşturun.',
                  icon: Icons.groups_outlined,
                );
              }

              return Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final group in groups)
                      SwitchListTile(
                        value: _student.groupIds.contains(group.id),
                        title: Text(group.name),
                        subtitle: Text('${group.memberCount} üye'),
                        secondary: const Icon(Icons.groups_rounded),
                        onChanged: _busy ? null : (value) => _toggle(group, value),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(AppGroup group, bool add) async {
    final admin = context.read<AdminController>();
    final users = context.read<UserRepository>();
    setState(() => _busy = true);

    try {
      if (add) {
        await admin.addMembers(group.id, [_student.id]);
      } else {
        await admin.removeMembers(group.id, [_student.id]);
      }
      // Ayna sunucuda güncellendi; yerel kopyayı tazele ki switch doğru görünsün.
      final refreshed = await users.getUser(_student.id);
      if (!mounted) return;
      setState(() {
        if (refreshed != null) _student = refreshed;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(add ? '${group.name} grubuna eklendi.' : '${group.name} grubundan çıkarıldı.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $error')),
      );
    }
  }
}
