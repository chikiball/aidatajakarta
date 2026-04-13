"""
Indonesian Holiday Calendar for 2024-2026
Includes public holidays, religious holidays, and school holidays.
"""
from datetime import date, timedelta

# Indonesian Public Holidays 2024-2026
# Format: (date, name, is_religious, is_majority_religion_islam)
HOLIDAYS = {
    # ─── 2024 ───
    date(2024, 1, 1): ("Tahun Baru Masehi", False, False),
    date(2024, 2, 8): ("Isra Mi'raj Nabi Muhammad SAW", True, True),
    date(2024, 2, 10): ("Tahun Baru Imlek", True, False),
    date(2024, 3, 11): ("Hari Suci Nyepi", True, False),
    date(2024, 3, 28): ("Cuti Bersama Hari Raya Idul Fitri", True, True),
    date(2024, 3, 29): ("Wafat Isa Al Masih", True, False),
    date(2024, 3, 31): ("Hari Paskah", True, False),
    date(2024, 4, 8): ("Cuti Bersama Hari Raya Idul Fitri", True, True),
    date(2024, 4, 9): ("Cuti Bersama Hari Raya Idul Fitri", True, True),
    date(2024, 4, 10): ("Hari Raya Idul Fitri 1445 H", True, True),
    date(2024, 4, 11): ("Hari Raya Idul Fitri 1445 H", True, True),
    date(2024, 4, 12): ("Cuti Bersama Hari Raya Idul Fitri", True, True),
    date(2024, 4, 15): ("Cuti Bersama Hari Raya Idul Fitri", True, True),
    date(2024, 5, 1): ("Hari Buruh Internasional", False, False),
    date(2024, 5, 9): ("Kenaikan Isa Al Masih", True, False),
    date(2024, 5, 23): ("Hari Raya Waisak", True, False),
    date(2024, 5, 24): ("Cuti Bersama Hari Raya Waisak", True, False),
    date(2024, 6, 1): ("Hari Lahir Pancasila", False, False),
    date(2024, 6, 17): ("Hari Raya Idul Adha 1445 H", True, True),
    date(2024, 6, 18): ("Cuti Bersama Idul Adha", True, True),
    date(2024, 7, 7): ("Tahun Baru Islam 1446 H", True, True),
    date(2024, 8, 17): ("Hari Kemerdekaan RI", False, False),
    date(2024, 9, 16): ("Maulid Nabi Muhammad SAW", True, True),
    date(2024, 12, 25): ("Hari Natal", True, False),
    date(2024, 12, 26): ("Cuti Bersama Natal", True, False),

    # ─── 2025 ───
    date(2025, 1, 1): ("Tahun Baru Masehi", False, False),
    date(2025, 1, 27): ("Isra Mi'raj Nabi Muhammad SAW", True, True),
    date(2025, 1, 29): ("Tahun Baru Imlek", True, False),
    date(2025, 3, 14): ("Cuti Bersama Hari Raya Idul Fitri", True, True),
    date(2025, 3, 28): ("Cuti Bersama Hari Raya Idul Fitri", True, True),
    date(2025, 3, 29): ("Hari Suci Nyepi", True, False),
    date(2025, 3, 31): ("Hari Raya Idul Fitri 1446 H", True, True),
    date(2025, 4, 1): ("Hari Raya Idul Fitri 1446 H", True, True),
    date(2025, 4, 2): ("Cuti Bersama Hari Raya Idul Fitri", True, True),
    date(2025, 4, 3): ("Cuti Bersama Hari Raya Idul Fitri", True, True),
    date(2025, 4, 4): ("Cuti Bersama Hari Raya Idul Fitri", True, True),
    date(2025, 4, 7): ("Cuti Bersama Hari Raya Idul Fitri", True, True),
    date(2025, 4, 18): ("Wafat Isa Al Masih", True, False),
    date(2025, 5, 1): ("Hari Buruh Internasional", False, False),
    date(2025, 5, 12): ("Hari Raya Waisak", True, False),
    date(2025, 5, 29): ("Kenaikan Isa Al Masih", True, False),
    date(2025, 6, 1): ("Hari Lahir Pancasila", False, False),
    date(2025, 6, 6): ("Hari Raya Idul Adha 1446 H", True, True),
    date(2025, 6, 7): ("Cuti Bersama Idul Adha", True, True),
    date(2025, 6, 27): ("Tahun Baru Islam 1447 H", True, True),
    date(2025, 8, 17): ("Hari Kemerdekaan RI", False, False),
    date(2025, 9, 5): ("Maulid Nabi Muhammad SAW", True, True),
    date(2025, 12, 25): ("Hari Natal", True, False),
    date(2025, 12, 26): ("Cuti Bersama Natal", True, False),

    # ─── 2026 ───
    date(2026, 1, 1): ("Tahun Baru Masehi", False, False),
    date(2026, 1, 16): ("Isra Mi'raj Nabi Muhammad SAW", True, True),
    date(2026, 2, 17): ("Tahun Baru Imlek", True, False),
    date(2026, 3, 19): ("Hari Suci Nyepi", True, False),
    date(2026, 3, 20): ("Hari Raya Idul Fitri 1447 H", True, True),
    date(2026, 3, 21): ("Hari Raya Idul Fitri 1447 H", True, True),
    date(2026, 4, 3): ("Wafat Isa Al Masih", True, False),
    date(2026, 5, 1): ("Hari Buruh Internasional", False, False),
    date(2026, 5, 14): ("Kenaikan Isa Al Masih", True, False),
    date(2026, 5, 27): ("Hari Raya Idul Adha 1447 H", True, True),
    date(2026, 5, 31): ("Hari Raya Waisak", True, False),
    date(2026, 6, 1): ("Hari Lahir Pancasila", False, False),
    date(2026, 6, 17): ("Tahun Baru Islam 1448 H", True, True),
    date(2026, 8, 17): ("Hari Kemerdekaan RI", False, False),
    date(2026, 8, 26): ("Maulid Nabi Muhammad SAW", True, True),
    date(2026, 12, 25): ("Hari Natal", True, False),
}

# Ramadan periods (approximate, based on Islamic calendar)
RAMADAN_PERIODS = [
    (date(2024, 3, 12), date(2024, 4, 9)),   # Ramadan 1445 H
    (date(2025, 3, 1), date(2025, 3, 30)),    # Ramadan 1446 H
    (date(2026, 2, 18), date(2026, 3, 19)),   # Ramadan 1447 H
]

# School holiday periods (approximate, Indonesian academic calendar)
SCHOOL_HOLIDAYS = [
    # 2024
    (date(2024, 3, 25), date(2024, 4, 15)),   # Semester break / Eid
    (date(2024, 6, 22), date(2024, 7, 14)),   # Mid-year break
    (date(2024, 12, 21), date(2025, 1, 5)),   # Year-end break
    # 2025
    (date(2025, 3, 24), date(2025, 4, 7)),    # Semester break / Eid
    (date(2025, 6, 21), date(2025, 7, 13)),   # Mid-year break
    (date(2025, 12, 20), date(2026, 1, 4)),   # Year-end break
    # 2026
    (date(2026, 3, 14), date(2026, 3, 28)),   # Semester break / Eid
    (date(2026, 6, 20), date(2026, 7, 12)),   # Mid-year break
]


def is_public_holiday(d: date) -> bool:
    return d in HOLIDAYS

def get_holiday_name(d: date) -> str:
    return HOLIDAYS.get(d, (None,))[0]

def is_religious_holiday(d: date) -> bool:
    info = HOLIDAYS.get(d)
    return info[1] if info else False

def is_islamic_holiday(d: date) -> bool:
    info = HOLIDAYS.get(d)
    return info[2] if info else False

def is_ramadan(d: date) -> bool:
    return any(start <= d <= end for start, end in RAMADAN_PERIODS)

def is_school_holiday(d: date) -> bool:
    return any(start <= d <= end for start, end in SCHOOL_HOLIDAYS)

def days_to_nearest_holiday(d: date) -> int:
    """Returns number of days to the nearest public holiday (past or future)."""
    all_dates = sorted(HOLIDAYS.keys())
    min_dist = 999
    for hd in all_dates:
        dist = abs((hd - d).days)
        if dist < min_dist:
            min_dist = dist
    return min_dist

def is_near_holiday(d: date, days: int = 3) -> bool:
    """Check if date is within N days of a holiday."""
    return days_to_nearest_holiday(d) <= days

def is_long_weekend(d: date) -> bool:
    """Check if date is part of a long weekend (holiday adjacent to weekend)."""
    dow = d.weekday()
    # Friday and Monday next to holiday weekend
    if dow == 4:  # Friday
        return is_public_holiday(d + timedelta(days=1)) or is_public_holiday(d - timedelta(days=1))
    if dow == 0:  # Monday
        return is_public_holiday(d - timedelta(days=1)) or is_public_holiday(d + timedelta(days=1))
    return False

def get_payday_proximity(d: date) -> int:
    """Days to nearest payday (25th or 1st of month)."""
    day = d.day
    if day <= 1:
        return 1 - day
    elif day <= 25:
        return min(day - 1, 25 - day)
    else:
        # Days remaining to next month's 1st
        import calendar
        days_in_month = calendar.monthrange(d.year, d.month)[1]
        return min(day - 25, days_in_month - day + 1)
