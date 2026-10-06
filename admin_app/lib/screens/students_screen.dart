import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/admin_controller.dart';
import 'student_groups_screen.dart';

/// Öğrenci yönetimi: listeleme, arama, oluşturma, düzenleme, silme.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenciler'),
        actions: [
          IconButton(
            tooltip: 'Yeni öğrenci',
            onPressed: () => _createStudent(context),
            icon: const Icon(Icons.person_add_alt_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: admin.setSearchTerm,
              decoration: InputDecoration(
                hintText: 'Ad, soyad veya e-posta ile ara…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          admin.setSearchTerm('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: admin.watchStudents(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const AppError(message: 'Öğrenciler yüklenemedi.');
                }
                if (!snapshot.hasData) return const AppLoading();

                final students = snapshot.data ?? const <AppUser>[];
                if (students.isEmpty) {
                  return AppEmpty(
                    title: admin.searchTerm.isEmpty ? 'Henüz öğrenci yok' : 'Sonuç bulunamadı',
                    description: admin.searchTerm.isEmpty
                        ? 'Sağ üstteki düğmeden yeni öğrenci ekleyebilirsiniz.'
                        : 'Farklı bir arama terimi deneyin.',
                    icon: Icons.person_search_rounded,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Card(
                      child: ListTile(
                        onTap: () => _showActions(context, student),
                        leading: AppAvatar(
                          initials: student.initials,
                          imageUrl: student.profileImage,
                        ),
                        title: Text(student.fullName.isEmpty ? student.email : student.fullName),
                        subtitle: Text(
                          '${student.email} · ${student.groupIds.length} grup',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: student.isActive
                            ? RoleBadge(role: student.role)
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Pasif',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onErrorContainer,
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createStudent(BuildContext context) async {
    final result = await showDialog<({String name, String surname, String email, String password})>(
      context: context,
      builder: (_) => const _StudentFormDialog(),
    );
    if (result == null || !context.mounted) return;

    try {
      await context.read<AdminController>().createStudent(
            name: result.name,
            surname: result.surname,
            email: result.email,
            password: result.password,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.email} için hesap oluşturuldu.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hesap oluşturulamadı: $error')),
      );
    }
  }

  Future<void> _showActions(BuildContext context, AppUser student) async {
    final admin = context.read<AdminController>();
    final navigator = Navigator.of(context);

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(student.fullName.isEmpty ? student.email : student.fullName),
              subtitle: Text(student.email),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: const Text('Grupları yönet'),
              subtitle: Text('${student.groupIds.length} grup üyeliği'),
              onTap: () {
                navigator.pop();
                StudentGroupsScreen.open(context, student);
              },
            ),
            ListTile(
              leading: Icon(
                student.isActive ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
              ),
              title: Text(student.isActive ? 'Pasifleştir' : 'Aktifleştir'),
              onTap: () async {
                navigator.pop();
                try {
                  await admin.updateUser(student, isActive: !student.isActive);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('İşlem başarısız: $error')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.error),
              title: Text(
                'Sil',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('Auth ve tüm veriler kalıcı olarak silinir'),
              onTap: () async {
                navigator.pop();
                if (!context.mounted) return;
                final confirmed = await confirmDialog(
                  context,
                  title: 'Öğrenciyi sil',
                  message: '${student.email} hesabı ve tüm verileri kalıcı olarak silinecek.',
                  confirmLabel: 'Sil',
                  destructive: true,
                );
                if (!confirmed || !context.mounted) return;
                try {
                  await admin.deleteUser(student.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Öğrenci silindi.')),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Silinemedi: $error')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Yeni öğrenci formu. Hesap **sunucuda** oluşturulur; şifre öğrenciyle paylaşılır.
class _StudentFormDialog extends StatefulWidget {
  const _StudentFormDialog();

  @override
  State<_StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<_StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Yeni öğrenci'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Ad'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Zorunlu' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _surname,
                  decoration: const InputDecoration(labelText: 'Soyad'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-posta'),
                  validator: (value) =>
                      (value == null || !value.contains('@')) ? 'Geçerli bir e-posta girin.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Geçici şifre',
                    helperText: 'Öğrenciye iletilecek, en az 8 karakter',
                  ),
                  validator: (value) =>
                      (value == null || value.length < 8) ? 'En az 8 karakter olmalı.' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                (
                  name: _name.text.trim(),
                  surname: _surname.text.trim(),
                  email: _email.text.trim(),
                  password: _password.text,
                ),
              );
            },
            child: const Text('Oluştur'),
          ),
        ],
      );
}
