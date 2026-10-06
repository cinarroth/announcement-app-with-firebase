import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_comm/school_comm.dart';

import '../state/student_data_controller.dart';
import 'group_detail_screen.dart';

/// Öğrencinin üye olduğu gruplar.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StudentDataController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Gruplarım')),
      body: data.loading
          ? const AppLoading()
          : data.myGroups.isEmpty
              ? const AppEmpty(
                  title: 'Grup bulunmuyor',
                  description:
                      'Henüz bir sınıfa atanmadınız. Yönetici sizi bir gruba eklediğinde '
                      'burada listelenecek.',
                  icon: Icons.groups_outlined,
                )
              : RefreshIndicator(
                  onRefresh: () async => context.read<StudentDataController>().refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: data.myGroups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final group = data.myGroups[index];
                      return GroupTile(
                        group: group,
                        subtitle: '${group.memberCount} üye · ${group.description}',
                        onTap: () => GroupDetailScreen.open(context, group.id),
                      );
                    },
                  ),
                ),
    );
  }
}
