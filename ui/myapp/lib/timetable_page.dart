// lib/timetable_page.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

/// Timetable page — single-file CSP + GA hybrid (class scheduling).
/// Drop into `lib/timetable_page.dart` and use / route to it.

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ---------- Config ----------
  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  int periodsPerDay = 6; // editable
  List<String> get periods =>
      [for (int i = 1; i <= periodsPerDay; i++) 'P$i'];

  // ---------- Models (local) ----------
  final List<DepartmentModel> departments = [];
  final List<RoomModel> rooms = [];

  Map<String, Map<String, Map<String, TimetableCell>>>? timetableResult;

  // GA state
  bool _isGenerating = false;
  String _status = '';

  // UI controllers for adding department/room quickly
  final TextEditingController _deptCtl = TextEditingController();
  final TextEditingController _roomCtl = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Sample starter data
    final d1 = DepartmentModel(name: 'Computer Science');
    d1.groups.addAll(['CS-A', 'CS-B']);
    d1.sessions.addAll([
      SessionInput(subject: 'Math', teacher: 'Alice', group: 'CS-A'),
      SessionInput(subject: 'Prog', teacher: 'Bob', group: 'CS-B'),
      SessionInput(subject: 'DS', teacher: 'Alice', group: 'CS-B'),
    ]);

    final d2 = DepartmentModel(name: 'Mechanical');
    d2.groups.addAll(['ME-A']);
    d2.sessions.addAll([
      SessionInput(subject: 'Thermo', teacher: 'Charlie', group: 'ME-A'),
      SessionInput(subject: 'MechLab', teacher: 'Dave', group: 'ME-A'),
    ]);

    departments.addAll([d1, d2]);
    rooms.addAll([RoomModel(name: 'Room 101'), RoomModel(name: 'Lab A'), RoomModel(name: 'Room 102')]);
  }

  @override
  void dispose() {
    _deptCtl.dispose();
    _roomCtl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ---------- Utility builders ----------
  List<String> getTimeslotIds() {
    final ids = <String>[];
    for (final d in days) {
      for (final p in periods) {
        ids.add('$d-$p');
      }
    }
    return ids;
  }

  // ---------- CSP Preprocessing ----------
  /// Returns a timetable structure:
  /// { departmentName: { day: { period: TimetableCell } } }
  Map<String, Map<String, Map<String, TimetableCell>>> applyCSP() {
    // empty timetable
    final table = <String, Map<String, Map<String, TimetableCell>>>{};
    for (final dept in departments) {
      table[dept.name] = <String, Map<String, TimetableCell>>{};
      for (final d in days) {
        table[dept.name]![d] = <String, TimetableCell>{};
        for (final p in periods) {
          table[dept.name]![d]![p] = TimetableCell.empty(day: d, period: p);
        }
      }
    }

    // staff schedule per slot to avoid clashes: { 'Mon': {'P1': {teacher1, teacher2}}}
    final staffSchedule = <String, Map<String, Set<String>>>{};
    for (final d in days) {
      staffSchedule[d] = <String, Set<String>>{};
      for (final p in periods) {
        staffSchedule[d]![p] = <String>{};
      }
    }

    // room schedule per slot: { 'Mon': {'P1': {room1}}}
    final roomSchedule = <String, Map<String, Set<String>>>{};
    for (final d in days) {
      roomSchedule[d] = <String, Set<String>>{};
      for (final p in periods) {
        roomSchedule[d]![p] = <String>{};
      }
    }

    final rand = Random();

    // assign sessions greedily: iterate days->periods->departments, try assign a session whose teacher free and a room free
    for (final d in days) {
      for (final p in periods) {
        // shuffle department order for variability
        final deptOrder = List<DepartmentModel>.from(departments)..shuffle(rand);
        for (final dept in deptOrder) {
          // select a session candidate randomly from dept.sessions
          final sessions = List<SessionInput>.from(dept.sessions)..shuffle(rand);
          var assigned = false;
          for (final s in sessions) {
            if (s.teacher != '' && staffSchedule[d]![p]!.contains(s.teacher)) {
              // teacher busy, skip
              continue;
            }
            // find a free room
            RoomModel? chosenRoom;
            for (final r in rooms) {
              if (!roomSchedule[d]![p]!.contains(r.name)) {
                chosenRoom = r;
                break;
              }
            }
            if (chosenRoom == null) {
              // no room free — cannot assign this slot for this department
              continue;
            }
            // assign
            table[dept.name]![d]![p] = TimetableCell(
              subject: s.subject,
              teacher: s.teacher,
              group: s.group,
              room: chosenRoom.name,
              day: d,
              period: p,
            );
            // mark teacher and room occupied
            if (s.teacher != '') staffSchedule[d]![p]!.add(s.teacher);
            roomSchedule[d]![p]!.add(chosenRoom.name);
            assigned = true;
            break;
          }
          if (!assigned) {
            // leave Free (already empty)
            table[dept.name]![d]![p] = TimetableCell.empty(day: d, period: p);
          }
        } // dept loop
      } // period loop
    } // day loop

    return table;
  }

  // ---------- GA optimization ----------
  // We represent a solution same shape as CSP table above.

  double fitness(Map<String, Map<String, Map<String, TimetableCell>>> sol) {
    // Higher is better.
    double score = 0.0;

    // 1) Penalize teacher clashes (should be rare due to CSP). Strong penalty.
    for (final d in days) {
      for (final p in periods) {
        final seen = <String, int>{};
        for (final deptName in sol.keys) {
          final t = sol[deptName]![d]![p]!;
          final teacher = t.teacher ?? '';
          if (teacher.isNotEmpty) {
            seen[teacher] = (seen[teacher] ?? 0) + 1;
          }
        }
        for (final v in seen.values) {
          if (v > 1) {
            score -= (v - 1) * 10.0;
          }
        }
      }
    }

    // 2) Reward balanced teacher loads (lower variance)
    final teacherCount = <String, int>{};
    for (final deptName in sol.keys) {
      for (final d in days) {
        for (final p in periods) {
          final t = sol[deptName]![d]![p]!;
          final teacher = t.teacher ?? '';
          if (teacher.isNotEmpty) teacherCount[teacher] = (teacherCount[teacher] ?? 0) + 1;
        }
      }
    }
    if (teacherCount.isNotEmpty) {
      final vals = teacherCount.values.map((e) => e.toDouble()).toList();
      final mean = vals.reduce((a, b) => a + b) / vals.length;
      final variance = vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / vals.length;
      // smaller variance = better -> add negative variance penalty
      score -= variance * 0.5;
      // reward overall assigned sessions
      final assigned = teacherCount.values.fold<int>(0, (p, e) => p + e);
      score += assigned * 0.1;
    }

    // 3) Penalize empty slots (soft) - encourage filling when possible
    int empties = 0;
    for (final deptName in sol.keys) {
      for (final d in days) {
        for (final p in periods) {
          final t = sol[deptName]![d]![p]!;
          if (t.isEmpty) empties++;
        }
      }
    }
    score -= empties * 0.05;

    return score;
  }

  Map<String, Map<String, Map<String, TimetableCell>>> mutateSolution(
      Map<String, Map<String, Map<String, TimetableCell>>> sol,
      double mutationRate,
      Random rng) {
    final result = deepCopySolution(sol);

    for (final deptName in result.keys) {
      if (rng.nextDouble() < mutationRate) {
        final day = days[rng.nextInt(days.length)];
        final p1 = periods[rng.nextInt(periods.length)];
        final p2 = periods[rng.nextInt(periods.length)];
        // swap cells within same dept/day
        final tmp = result[deptName]![day]![p1]!;
        result[deptName]![day]![p1] = result[deptName]![day]![p2]!;
        result[deptName]![day]![p2] = tmp;
      }
      // occasional replace with department random session in some slot
      if (rng.nextDouble() < mutationRate * 0.6) {
        final deptModel = departments.firstWhere((d) => d.name == deptName);
        if (deptModel.sessions.isNotEmpty) {
          final s = deptModel.sessions[rng.nextInt(deptModel.sessions.length)];
          final day = days[rng.nextInt(days.length)];
          final p = periods[rng.nextInt(periods.length)];
          // try assign if teacher not conflicting in that slot across other depts
          final teacher = s.teacher;
          var conflict = false;
          for (final otherDept in result.keys) {
            if (otherDept == deptName) continue;
            final other = result[otherDept]![day]![p]!;
            if (other.teacher == teacher && teacher.isNotEmpty) {
              conflict = true;
              break;
            }
          }
          if (!conflict) {
            // pick a room from available rooms (simple approach)
            final room = rooms.isNotEmpty ? rooms[rng.nextInt(rooms.length)].name : null;
            result[deptName]![day]![p] = TimetableCell(
              subject: s.subject,
              teacher: s.teacher,
              group: s.group,
              room: room,
              day: day,
              period: p,
            );
          }
        }
      }
    }

    return result;
  }

  Map<String, Map<String, Map<String, TimetableCell>>> crossoverSolution(
      Map<String, Map<String, Map<String, TimetableCell>>> a,
      Map<String, Map<String, Map<String, TimetableCell>>> b,
      Random rng) {
    final child = deepCopySolution(a);
    // swap for a subset of departments or days
    for (final deptName in child.keys) {
      if (rng.nextBool()) {
        // swap random day
        final day = days[rng.nextInt(days.length)];
        child[deptName]![day] = deepCopyDay(b[deptName]![day]!);
      }
    }
    return child;
  }

  Map<String, Map<String, Map<String, TimetableCell>>> deepCopySolution(
      Map<String, Map<String, Map<String, TimetableCell>>> sol) {
    final res = <String, Map<String, Map<String, TimetableCell>>>{};
    for (final deptName in sol.keys) {
      res[deptName] = <String, Map<String, TimetableCell>>{};
      for (final d in sol[deptName]!.keys) {
        res[deptName]![d] = <String, TimetableCell>{};
        for (final p in sol[deptName]![d]!.keys) {
          res[deptName]![d]![p] = sol[deptName]![d]![p]!.clone();
        }
      }
    }
    return res;
  }

  Map<String, TimetableCell> deepCopyDay(Map<String, TimetableCell> dayMap) {
    final m = <String, TimetableCell>{};
    for (final k in dayMap.keys) {
      m[k] = dayMap[k]!.clone();
    }
    return m;
  }

  // create initial population derived from CSP solution
  List<Map<String, Map<String, Map<String, TimetableCell>>>> buildInitialPopulation(
      Map<String, Map<String, Map<String, TimetableCell>>> csp,
      int popSize,
      Random rng) {
    final pop = <Map<String, Map<String, Map<String, TimetableCell>>>>[];
    for (int i = 0; i < popSize; i++) {
      final ind = deepCopySolution(csp);
      // apply a few random swaps to diversify
      final swaps = 2 + rng.nextInt(5);
      for (int j = 0; j < swaps; j++) {
        final dept = ind.keys.elementAt(rng.nextInt(ind.keys.length));
        final day = days[rng.nextInt(days.length)];
        final p1 = periods[rng.nextInt(periods.length)];
        final p2 = periods[rng.nextInt(periods.length)];
        final tmp = ind[dept]![day]![p1]!;
        ind[dept]![day]![p1] = ind[dept]![day]![p2]!;
        ind[dept]![day]![p2] = tmp;
      }
      pop.add(ind);
    }
    return pop;
  }

  Future<void> runHybridSolver({int popSize = 30, int generations = 80, double mutationRate = 0.08}) async {
    setState(() {
      _isGenerating = true;
      _status = 'Running CSP...';
      timetableResult = null;
    });

    // 1. CSP
    final csp = applyCSP();
    await Future<void>.delayed(const Duration(milliseconds: 150)); // small pause for UX

    setState(() {
      _status = 'Preparing GA population...';
    });

    final rng = Random();
    var population = buildInitialPopulation(csp, popSize, rng);

    // simple GA loop
    Map<String, Map<String, Map<String, TimetableCell>>> best = population[0];
    double bestScore = -double.infinity;

    for (int gen = 0; gen < generations; gen++) {
      if (!mounted) break;
      // evaluate fitness
      final scored = <MapEntry<Map<String, Map<String, Map<String, TimetableCell>>>, double>>[];
      for (final ind in population) {
        final s = fitness(ind);
        scored.add(MapEntry(ind, s));
        if (s > bestScore) {
          bestScore = s;
          best = deepCopySolution(ind);
        }
      }
      // sort descending
      scored.sort((a, b) => b.value.compareTo(a.value));
      // take top 30%
      final retainCount = max(2, (scored.length * 0.3).floor());
      final nextGen = <Map<String, Map<String, Map<String, TimetableCell>>>>[];
      for (int i = 0; i < retainCount; i++) nextGen.add(scored[i].key);

      // generate rest by crossover + mutation from top half
      while (nextGen.length < popSize) {
        final parents = scored.sublist(0, max(2, (scored.length / 2).floor()));
        final p1 = parents[rng.nextInt(parents.length)].key;
        final p2 = parents[rng.nextInt(parents.length)].key;
        final child = crossoverSolution(p1, p2, rng);
        final mutated = mutateSolution(child, mutationRate, rng);
        nextGen.add(mutated);
      }

      population = nextGen;

      // update UI periodically
      if (gen % max(1, (generations / 8).floor()) == 0) {
        setState(() {
          _status = 'GA gen ${gen + 1}/$generations — best=${bestScore.toStringAsFixed(2)}';
        });
        // small delay to keep UI responsive
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    setState(() {
      _isGenerating = false;
      timetableResult = best;
      _status = 'Done — best score ${bestScore.toStringAsFixed(2)}';
      _tabController.animateTo(2);
    });
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable (Local CSP + GA)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Departments'),
            Tab(icon: Icon(Icons.play_arrow), text: 'Generate'),
            Tab(icon: Icon(Icons.grid_on), text: 'Timetable'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDepartmentsTab(),
          _buildGenerateTab(),
          _buildTimetableTab(),
        ],
      ),
    );
  }

  Widget _buildDepartmentsTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: _deptCtl, decoration: const InputDecoration(hintText: 'Department name'))),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final name = _deptCtl.text.trim();
              if (name.isEmpty) return;
              setState(() {
                departments.add(DepartmentModel(name: name));
                _deptCtl.clear();
              });
            },
            child: const Text('Add Dept'),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _roomCtl, decoration: const InputDecoration(hintText: 'Room name (optional)'))),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final r = _roomCtl.text.trim();
              if (r.isEmpty) return;
              setState(() {
                rooms.add(RoomModel(name: r));
                _roomCtl.clear();
              });
            },
            child: const Text('Add Room'),
          ),
        ]),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: Text('Rooms: ${rooms.map((r) => r.name).join(", ")}',
            style: const TextStyle(fontStyle: FontStyle.italic))),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: departments.length,
            itemBuilder: (ctx, idx) {
              final dept = departments[idx];
              return Card(
                child: ExpansionTile(
                  title: Row(children: [
                    Expanded(child: Text(dept.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      onPressed: () {
                        setState(() => departments.removeAt(idx));
                      },
                    ),
                  ]),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Sessions', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ...dept.sessions.asMap().entries.map((e) {
                          final s = e.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${s.subject}'),
                            subtitle: Text('${s.teacher} • ${s.group}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => setState(() => dept.sessions.removeAt(e.key)),
                            ),
                          );
                        }),
                        const Divider(),
                        _SessionAdder(
                          onAdd: (subject, teacher, group) {
                            setState(() {
                              dept.sessions.add(SessionInput(subject: subject, teacher: teacher, group: group));
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Groups: ${dept.groups.join(", ")}', style: const TextStyle(fontStyle: FontStyle.italic)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  final g = 'G${dept.groups.length + 1}';
                                  dept.groups.add(g);
                                });
                              },
                              icon: const Icon(Icons.group_add),
                              label: const Text('Add Group'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (dept.groups.isNotEmpty) {
                                  setState(() {
                                    dept.groups.removeLast();
                                  });
                                }
                              },
                              icon: const Icon(Icons.remove_circle_outline),
                              label: const Text('Remove Group'),
                            ),
                          ],
                        ),
                      ]),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildGenerateTab() {
    final preview = jsonEncode(_previewRequest());
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(JsonEncoder.withIndent('  ').convert(_previewRequest())),
              ),
            ),
          ),
        ),
        Row(
          children: [
            const Text('Periods/day:'),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                min: 4,
                max: 8,
                divisions: 4,
                value: periodsPerDay.toDouble(),
                label: periodsPerDay.toString(),
                onChanged: (v) {
                  setState(() {
                    periodsPerDay = v.round();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Text('$periodsPerDay'),
          ],
        ),
        const SizedBox(height: 8),
        _isGenerating
            ? Column(children: [
                Text(_status),
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // do nothing for now (we don't implement cancellation)
                  },
                  icon: const Icon(Icons.hourglass_bottom),
                  label: const Text('Generating...'),
                )
              ])
            : Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => runHybridSolver(popSize: 28, generations: 100, mutationRate: 0.08),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Generate Timetable (Local CSP+GA)'),
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 8),
        Text(_status, style: const TextStyle(fontStyle: FontStyle.italic)),
      ]),
    );
  }

  Map<String, dynamic> _previewRequest() {
    return {
      'departments': departments.map((d) => d.toJson()).toList(),
      'rooms': rooms.map((r) => r.toJson()).toList(),
      'days': days,
      'periodsPerDay': periodsPerDay,
    };
  }

  Widget _buildTimetableTab() {
    if (timetableResult == null) {
      return const Center(child: Text('No timetable generated yet. Use Generate tab.'));
    }

    final entries = timetableResult!.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (ctx, idx) {
        final deptName = entries[idx].key;
        final dayMap = entries[idx].value; // Map<String, Map<String, TimetableCell>>
        // compute max periods (should be periodsPerDay)
        final maxCols = periodsPerDay;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(deptName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  children: [
                    TableRow(children: [
                      const Padding(padding: EdgeInsets.all(8), child: Text('Day', style: TextStyle(fontWeight: FontWeight.w700))),
                      for (int c = 0; c < maxCols; c++)
                        Padding(padding: const EdgeInsets.all(8), child: Text('P${c + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                    for (final d in days)
                      TableRow(children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(d, style: const TextStyle(fontWeight: FontWeight.w600))),
                        for (int c = 0; c < maxCols; c++)
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: _renderCell(dayMap[d]![periods[c]]!),
                          ),
                      ]),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _renderCell(TimetableCell cell) {
    if (cell.isEmpty) {
      return Container(
        width: 160,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
        child: const Text('Free', style: TextStyle(color: Colors.grey)),
      );
    }
    final color = _colorForSubject(cell.subject ?? '');
    return Container(
      width: 160,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(cell.subject ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(cell.teacher ?? '', style: const TextStyle(fontSize: 12)),
        Text(cell.group ?? '', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        Text(cell.room ?? '-', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
      ]),
    );
  }

  Color _colorForSubject(String subject) {
    if (subject.isEmpty) return Colors.grey.shade200;
    final seed = subject.codeUnits.fold<int>(0, (p, e) => p + e);
    final rng = Random(seed);
    final hue = rng.nextInt(360);
    return HSVColor.fromAHSV(1, hue.toDouble(), 0.45, 0.95).toColor();
  }
}

// ---------- Small helper widget to add a session ----------
class _SessionAdder extends StatefulWidget {
  final void Function(String subject, String teacher, String group) onAdd;
  const _SessionAdder({required this.onAdd});

  @override
  State<_SessionAdder> createState() => _SessionAdderState();
}


class _SessionAdderState extends State<_SessionAdder> {
  final TextEditingController _subj = TextEditingController();
  final TextEditingController _teacher = TextEditingController();
  final TextEditingController _group = TextEditingController();

  @override
  void dispose() {
    _subj.dispose();
    _teacher.dispose();
    _group.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(controller: _subj, decoration: const InputDecoration(hintText: 'Subject')),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: _teacher, decoration: const InputDecoration(hintText: 'Teacher'))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _group, decoration: const InputDecoration(hintText: 'Group'))),
      ]),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: ElevatedButton.icon(
          onPressed: () {
            final subj = _subj.text.trim();
            final teacher = _teacher.text.trim();
            final group = _group.text.trim();
            if (subj.isEmpty || teacher.isEmpty || group.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter subject, teacher and group')));
              return;
            }
            widget.onAdd(subj, teacher, group);
            _subj.clear();
            _teacher.clear();
            _group.clear();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Session'),
        ),
      )
    ]);
  }
}

// ---------- Models ----------
class SessionInput {
  String subject;
  String teacher;
  String group;
  SessionInput({required this.subject, required this.teacher, required this.group});
  Map<String, dynamic> toJson() => {'subject': subject, 'teacher': teacher, 'group': group};
}

class DepartmentModel {
  String name;
  List<String> groups = [];
  List<SessionInput> sessions = [];
  DepartmentModel({required this.name});
  Map<String, dynamic> toJson() => {'name': name, 'groups': groups, 'sessions': sessions.map((s) => s.toJson()).toList()};
}

class RoomModel {
  String name;
  RoomModel({required this.name});
  Map<String, dynamic> toJson() => {'name': name};
}

/// The timetable cell assigned to a timeslot for a department
class TimetableCell {
  final String? subject;
  final String? teacher;
  final String? group;
  final String? room;
  final String day;
  final String period;

  TimetableCell({
    required this.subject,
    required this.teacher,
    required this.group,
    required this.room,
    required this.day,
    required this.period,
  });

  TimetableCell.empty({required this.day, required this.period})
      : subject = null,
        teacher = null,
        group = null,
        room = null;

  bool get isEmpty => subject == null || subject!.isEmpty;

  TimetableCell clone() {
    return TimetableCell(subject: subject, teacher: teacher, group: group, room: room, day: day, period: period);
  }

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'teacher': teacher,
        'group': group,
        'room': room,
        'day': day,
        'period': period,
      };
}
