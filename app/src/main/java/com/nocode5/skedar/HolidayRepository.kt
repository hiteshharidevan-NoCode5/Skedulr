package com.nocode5.skedar

import java.util.Calendar

data class HolidayInfo(
    val title: String,
    val type: String
)

object HolidayRepository {

    private val fixedDates = mapOf(
        "2026-01-01" to listOf(HolidayInfo("New Year's Day (Court/Bank)", "BANK_COURT")),
        "2026-01-14" to listOf(
            HolidayInfo("Makar Sankranti / Uttarayan / Pongal", "FESTIVAL"),
            HolidayInfo("Sabarimala Makaravilakku Festival", "SABARIMALA")
        ),
        "2026-01-20" to listOf(HolidayInfo("Sabarimala Temple Closes (Makaravilakku)", "SABARIMALA")),
        "2026-01-26" to listOf(HolidayInfo("Republic Day (National/Bank/Court)", "BANK_COURT")),
        "2026-02-12" to listOf(HolidayInfo("Sabarimala Opens - Kumbham Maasa Pooja", "SABARIMALA")),
        "2026-02-15" to listOf(HolidayInfo("Maha Shivaratri (Festival/Bank/Court)", "FESTIVAL")),
        "2026-02-17" to listOf(HolidayInfo("Sabarimala Closes - Kumbham Pooja", "SABARIMALA")),
        "2026-03-04" to listOf(HolidayInfo("Holi / Dhuleti (Festival/Bank/Court)", "FESTIVAL")),
        "2026-03-14" to listOf(HolidayInfo("Sabarimala Opens - Meenam & Uthram", "SABARIMALA")),
        "2026-03-20" to listOf(HolidayInfo("Eid-ul-Fitr (Festival/Bank/Court)", "FESTIVAL")),
        "2026-03-24" to listOf(HolidayInfo("Sabarimala Closes - Meenam Pooja", "SABARIMALA")),
        "2026-03-27" to listOf(HolidayInfo("Ram Navami (Festival/Court)", "FESTIVAL")),
        "2026-03-31" to listOf(HolidayInfo("Mahavir Jayanti (Festival/Bank/Court)", "FESTIVAL")),
        "2026-04-01" to listOf(HolidayInfo("Annual Bank Closing Day (Bank Holiday)", "BANK_COURT")),
        "2026-04-03" to listOf(HolidayInfo("Good Friday (Bank/Court Holiday)", "BANK_COURT")),
        "2026-04-10" to listOf(HolidayInfo("Sabarimala Opens - Vishu Festival", "SABARIMALA")),
        "2026-04-14" to listOf(HolidayInfo("Ambedkar Jayanti / Vishu (Bank/Court/Festival)", "FESTIVAL")),
        "2026-04-18" to listOf(HolidayInfo("Sabarimala Closes - Vishu", "SABARIMALA")),
        "2026-05-01" to listOf(HolidayInfo("Buddha Purnima / Maharashtra & Gujarat Day", "BANK_COURT")),
        "2026-05-14" to listOf(HolidayInfo("Sabarimala Opens - Edavam Maasa Pooja", "SABARIMALA")),
        "2026-05-19" to listOf(HolidayInfo("Sabarimala Closes - Edavam Pooja", "SABARIMALA")),
        "2026-05-27" to listOf(HolidayInfo("Bakrid / Eid-ul-Adha (Bank/Court)", "FESTIVAL")),
        "2026-06-15" to listOf(HolidayInfo("Sabarimala Opens - Mithunam Maasa Pooja", "SABARIMALA")),
        "2026-06-19" to listOf(HolidayInfo("Sabarimala Closes - Mithunam Pooja", "SABARIMALA")),
        "2026-06-26" to listOf(HolidayInfo("Muharram (Bank/Court Holiday)", "BANK_COURT")),
        "2026-07-16" to listOf(HolidayInfo("Sabarimala Opens - Karkidakam Maasa Pooja", "SABARIMALA")),
        "2026-07-20" to listOf(HolidayInfo("Sabarimala Closes - Karkidakam Pooja", "SABARIMALA")),
        "2026-08-15" to listOf(HolidayInfo("Independence Day (National/Bank/Court)", "BANK_COURT")),
        "2026-08-16" to listOf(HolidayInfo("Sabarimala Opens - Chingam & Onam", "SABARIMALA")),
        "2026-08-26" to listOf(HolidayInfo("Onam / Thiruvonam & Eid-e-Milad", "FESTIVAL")),
        "2026-08-28" to listOf(HolidayInfo("Raksha Bandhan (Festival/Court)", "FESTIVAL")),
        "2026-09-04" to listOf(HolidayInfo("Janmashtami (Festival/Bank/Court)", "FESTIVAL")),
        "2026-09-14" to listOf(HolidayInfo("Ganesh Chaturthi (Festival/Bank)", "FESTIVAL")),
        "2026-09-16" to listOf(HolidayInfo("Sabarimala Opens - Kanni Maasa Pooja", "SABARIMALA")),
        "2026-09-21" to listOf(HolidayInfo("Sabarimala Closes - Kanni Pooja", "SABARIMALA")),
        "2026-10-02" to listOf(HolidayInfo("Gandhi Jayanti (National/Bank/Court)", "BANK_COURT")),
        "2026-10-17" to listOf(HolidayInfo("Sabarimala Opens - Thulam Maasa Pooja", "SABARIMALA")),
        "2026-10-20" to listOf(HolidayInfo("Dussehra / Vijayadashami (Festival/Bank/Court)", "FESTIVAL")),
        "2026-10-22" to listOf(HolidayInfo("Sabarimala Closes - Thulam Pooja", "SABARIMALA")),
        "2026-11-08" to listOf(HolidayInfo("Diwali / Deepavali (Festival/Bank/Court)", "FESTIVAL")),
        "2026-11-09" to listOf(HolidayInfo("Gujarati New Year / Govardhan Puja", "FESTIVAL")),
        "2026-11-11" to listOf(HolidayInfo("Bhai Dooj (Festival/Court)", "FESTIVAL")),
        "2026-11-16" to listOf(HolidayInfo("Sabarimala Opens - Mandala Kalam Begins", "SABARIMALA")),
        "2026-11-24" to listOf(HolidayInfo("Guru Nanak Jayanti (Festival/Bank/Court)", "FESTIVAL")),
        "2026-12-25" to listOf(HolidayInfo("Christmas Day (Festival/Bank/Court)", "BANK_COURT")),
        "2026-12-27" to listOf(HolidayInfo("Sabarimala Mandala Pooja (Temple Closes Night)", "SABARIMALA")),
        "2026-12-30" to listOf(HolidayInfo("Sabarimala Reopens - Makaravilakku Season", "SABARIMALA")),
        "2027-01-14" to listOf(
            HolidayInfo("Makar Sankranti / Pongal", "FESTIVAL"),
            HolidayInfo("Sabarimala Makaravilakku Festival", "SABARIMALA")
        ),
        "2027-01-20" to listOf(HolidayInfo("Sabarimala Temple Closes (Makaravilakku)", "SABARIMALA")),
        "2027-01-26" to listOf(HolidayInfo("Republic Day (National/Bank/Court)", "BANK_COURT"))
    )

    fun getHolidaysForDate(year: Int, monthZeroBased: Int, day: Int): List<HolidayInfo> {
        val result = mutableListOf<HolidayInfo>()
        val key = String.format("%04d-%02d-%02d", year, monthZeroBased + 1, day)
        fixedDates[key]?.let { result.addAll(it) }

        val cal = Calendar.getInstance().apply { set(year, monthZeroBased, day) }
        val dow = cal.get(Calendar.DAY_OF_WEEK)
        if (dow == Calendar.SATURDAY) {
            val weekOfMonth = (day - 1) / 7 + 1
            if (weekOfMonth == 2 || weekOfMonth == 4) {
                result.add(HolidayInfo("${if (weekOfMonth == 2) "2nd" else "4th"} Saturday (Bank & Court Holiday)", "BANK_COURT"))
            }
        }
        if ((monthZeroBased == Calendar.NOVEMBER && day in 17..30) ||
            (monthZeroBased == Calendar.DECEMBER && day in 1..26) ||
            (monthZeroBased == Calendar.DECEMBER && day == 31) ||
            (monthZeroBased == Calendar.JANUARY && day in 1..19 && day != 14)) {
            result.add(HolidayInfo("Sabarimala Temple Open (Mandala-Makaravilakku)", "SABARIMALA"))
        }
        return result
    }

    fun getHolidayDaysInMonth(year: Int, monthZeroBased: Int): Map<Int, String> {
        val map = mutableMapOf<Int, String>()
        val cal = Calendar.getInstance().apply { set(year, monthZeroBased, 1) }
        val maxDay = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
        for (d in 1..maxDay) {
            val list = getHolidaysForDate(year, monthZeroBased, d)
            if (list.isNotEmpty()) {
                val priority = when {
                    list.any { it.type == "SABARIMALA" } -> "SABARIMALA"
                    list.any { it.type == "FESTIVAL" } -> "FESTIVAL"
                    else -> "BANK_COURT"
                }
                map[d] = priority
            }
        }
        return map
    }
}
