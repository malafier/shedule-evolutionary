import cython

cdef int H_PER_DAY = 8

cdef class Day:
    MON = 0 * H_PER_DAY
    TUE = 1 * H_PER_DAY
    WED = 2 * H_PER_DAY
    THU = 3 * H_PER_DAY
    FRI = 4 * H_PER_DAY

    cdef list _days

    def __cinit__(self):
        self._days = [self.MON, self.TUE, self.WED, self.THU, self.FRI]

    def __iter__(self):
        return iter(self._days)

cpdef double basic_evaluation(list plan, list weight_per_hour):
    cdef double score = 0
    cdef int i, j
    cdef tuple lesson
    for gid in range(len(plan)):
        for i in range(len(plan[gid])):
            lesson = plan[gid][i]
            if lesson != (0, 0):
                score += weight_per_hour[i % H_PER_DAY]
    return score

cdef bint is_empty(list plan, int gid, int x_day, int start_h, int h_span):
    cdef list lessons = plan[gid][x_day + start_h: x_day + start_h + h_span - 1]
    cdef tuple lesson_before = plan[gid][x_day + start_h - 1]
    cdef tuple lesson_after = plan[gid][x_day + start_h + h_span]
    return all(lesson == (0, 0) for lesson in lessons) and lesson_after != (0, 0) and lesson_before != (0, 0)

cpdef double blank_lessons_evaluation(list plan):
    cdef double score = 0
    cdef int day_value, empty_size, lesson_h, i, j
    cdef tuple lesson, lesson_before, lesson_after

    for gid in range(len(plan)):
        for day in Day():
            for empty_size in range(1, 7):
                for lesson_h in range(1, H_PER_DAY - empty_size):
                    if is_empty(plan, gid, day, lesson_h, empty_size):
                        score += empty_size
    return 1 / score if score > 0 else 1

cpdef double hours_per_day_evaluation(list plan):
    cdef double score = 0
    cdef int hours, i
    cdef tuple lesson

    for gid in range(len(plan)):
        for day in Day():
            hours = 0
            for i in range(H_PER_DAY):
                lesson = plan[gid][day + i]
                if lesson != (0, 0):
                    hours += 1
            score += 1 if 3 <= hours <= 6 else -hours
    return score

cpdef double max_subject_hours_per_day_evaluation(list plan, list subjects):
    cdef double score = 0
    cdef int hours, gid, day
    cdef dict subject
    for gid in range(len(plan)):
        for day in Day():
            for subject in subjects[gid]:
                hours = 0
                for i in range(H_PER_DAY):
                    if plan[gid][day + i][0] == subject["id"]:
                        hours += 1
                score += 1 if hours <= 2 else -hours
    return score

cpdef double subject_block_evaluation(list plan, double reward, double punishment, list subjects):
    cdef double score = 0
    cdef int i
    cdef list hours
    cdef int day, gid
    cdef dict subject
    for gid in range(len(plan)):
        for day in Day():
            for subject in subjects[gid]:
                hours = []
                for i in range(H_PER_DAY):
                    if plan[gid][day + i][0] == subject["id"]:
                        hours.append(i)
                if len(hours) > 1:
                    for i in range(len(hours) - 1):
                        if hours[i + 1] - hours[i] == 1:
                            score += reward
                        else:
                            score += punishment
    return score

cpdef double teacher_block_evaluation(list plan, double reward, double punishment, list teachers):
    cdef double score = 0
    cdef int teacher_id
    cdef list lessons
    cdef int day, gid
    cdef int i
    cdef dict teacher
    cdef list lesson
    for teacher in teachers:
        teacher_id = teacher["id"]
        for day in Day():
            lessons = []
            for gid in range(len(plan)):
                for i in range(H_PER_DAY):
                    if plan[gid][day + i][1] == teacher_id:
                        lessons.append((gid, i))
            if len(lessons) > 1:
                for i in range(len(lessons) - 1):
                    if lessons[i + 1][1] - lessons[i][1] == 1:
                        score += reward
                    else:
                        score += punishment
    return score

cpdef double subject_at_end_or_start_evaluation(list plan, list subjects):
    cdef double score = 0
    cdef int day, gid
    cdef int i
    cdef dict subject
    cdef list special_subjects
    cdef int first_or_last
    for gid in range(len(plan)):
        special_subjects = [sub for sub in subjects[gid] if sub["start_end"]]
        for subject in special_subjects:
            for day in Day():
                for i in range(H_PER_DAY):
                    first_or_last = (
                            i == 0 or
                            i == H_PER_DAY - 1 or
                            all([plan[gid][day: day + i] == (0, 0)]) or
                            all([plan[gid][day: day + i][0] == subject["id"]]) or
                            all([plan[gid][day + i + 1: day + H_PER_DAY] == (0, 0)]) or
                            all([plan[gid][day + i + 1: day + H_PER_DAY][0] == subject["id"]])
                    )
                    if plan[gid][day + i][0] == subject["id"] and first_or_last:
                        score += 1
    return score
