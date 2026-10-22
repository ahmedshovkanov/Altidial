/// Board column for a task. Persisted as [dbIndex]; unknown values read as
/// backlog. Kept in `core/` so both `data/` and `features/projects/` can use it.
enum TaskStatus {
  backlog(0),
  todo(1),
  doing(2),
  blocked(3),
  done(4);

  const TaskStatus(this.dbIndex);
  final int dbIndex;

  static TaskStatus fromDb(int value) => TaskStatus.values.firstWhere(
    (s) => s.dbIndex == value,
    orElse: () => TaskStatus.backlog,
  );
}
