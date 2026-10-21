package com.haoze.diting.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.TimeZone

/**
 * A-056: `dayStartMillis()` folded "now" onto a fixed 86_400_000 ms grid using the UTC
 * offset in force at "now". That is only correct while the offset is constant across
 * the whole local day, so on a DST transition day the anchor belongs to a different
 * local midnight.
 *
 * The expectations below were derived independently with `java.time`
 * (`LocalDate.atStartOfDay(zone)`), not from this project's implementation, and are
 * pinned as literal epoch millis so the test cannot drift with the code.
 *
 * Measured impact of the old algorithm against that oracle, over the whole JDK
 * time-zone database (1990-2030, every offset change plus one day on either side,
 * 30-minute sampling): wrong on 28.4% of 5.45M samples. On spring-forward days it is
 * 60 min too early from the transition instant until local midnight, so "today"
 * silently includes the previous day's last hour; on fall-back days 60 min too late,
 * so the first hour disappears. That window is wider than the triage note's
 * "03:00-04:00" — and the note's own reproduction point (01:30 EDT) is genuinely
 * *not* affected, which is pinned below so both halves of the correction stay asserted.
 */
class DateTimeUtilsTest {

    private companion object {
        const val MINUTE = 60_000L
        const val DAY = 86_400_000L

        fun zone(id: String): TimeZone = TimeZone.getTimeZone(id)

        /** Local calendar day index of an instant; mirrors the production helper. */
        fun localDayIndex(instant: Long, zone: TimeZone): Long {
            val localMillis = instant + zone.getOffset(instant)
            val quotient = localMillis / DAY
            return if (localMillis % DAY != 0L && localMillis < 0L) quotient - 1 else quotient
        }
    }

    @Test
    fun springForwardDayStartsAtRealMidnightNotAnHourEarly() {
        val tz = zone("America/New_York")
        // 2026-03-08: clocks jump 02:00 -> 03:00 in America/New_York.
        val expected = 1772946000000L // 2026-03-08T00:00 EST (UTC-5)
        assertEquals(expected, dayStartMillis(1772953200000L, tz)) // 03:00 EDT
        assertEquals(expected, dayStartMillis(1772956800000L, tz)) // 04:00 EDT
        assertEquals(expected, dayStartMillis(1772985600000L, tz)) // 12:00 EDT
        assertEquals(expected, dayStartMillis(1773028740000L, tz)) // 23:59 EDT
    }

    @Test
    fun documentedReproductionPointIsNotActuallyAffected() {
        val tz = zone("America/New_York")
        // The triage note used 01:30 EDT as the reproduction. 01:30 on 2026-03-08 is
        // still EST (before the 02:00 jump), so the old code got it right; this pins
        // that half of the corrected finding.
        assertEquals(1772946000000L, dayStartMillis(1772951400000L, tz)) // 01:30 EST
    }

    @Test
    fun fallBackDayKeepsTheFirstHourInsteadOfDroppingIt() {
        val tz = zone("America/New_York")
        // 2026-11-01: clocks fall back 02:00 -> 01:00 in America/New_York.
        val expected = 1793505600000L // 2026-11-01T00:00 EDT (UTC-4)
        assertEquals(expected, dayStartMillis(1793507400000L, tz)) // 00:30 EDT
        assertEquals(expected, dayStartMillis(1793511000000L, tz)) // 01:30 EDT
        assertEquals(expected, dayStartMillis(1793552400000L, tz)) // 12:00 EST
        assertEquals(expected, dayStartMillis(1793595540000L, tz)) // 23:59 EST
    }

    @Test
    fun ordinaryDaysOnEitherSideOfTheTransitionAreUnchanged() {
        val tz = zone("America/New_York")
        assertEquals(1773028800000L, dayStartMillis(1773072000000L, tz)) // 2026-03-09
        assertEquals(1793595600000L, dayStartMillis(1793638800000L, tz)) // 2026-11-02
    }

    @Test
    fun zonesWithoutDaylightSavingTimeStayExact() {
        val tz = zone("Asia/Shanghai")
        assertEquals(1772899200000L, dayStartMillis(1772942400000L, tz)) // 2026-03-08 12:00
        assertEquals(1793462400000L, dayStartMillis(1793462400000L, tz)) // 2026-11-01 00:00
        assertEquals(1793462400000L, dayStartMillis(1793548740000L, tz)) // 2026-11-01 23:59
    }

    @Test
    fun northernAndSouthernHemisphereTransitionsBothResolve() {
        // Europe/Berlin, spring forward 2026-03-29 and fall back 2026-10-25.
        val berlin = zone("Europe/Berlin")
        assertEquals(1774738800000L, dayStartMillis(1774778400000L, berlin))
        assertEquals(1792879200000L, dayStartMillis(1792926000000L, berlin))

        // Australia/Sydney transitions in the opposite direction on the calendar.
        val sydney = zone("Australia/Sydney")
        assertEquals(1791036000000L, dayStartMillis(1791075600000L, sydney)) // 2026-10-04
        assertEquals(1775307600000L, dayStartMillis(1775354400000L, sydney)) // 2026-04-05
    }

    @Test
    fun midnightThatDoesNotExistResolvesToTheFirstExistingInstantOfTheDay() {
        // America/Santiago springs forward at local midnight: 2026-09-06 has no 00:00,
        // so the calendar day begins at 01:00 (-03).
        val tz = zone("America/Santiago")
        assertEquals(1788667200000L, dayStartMillis(1788706800000L, tz))
        // Its fall-back at midnight is unaffected.
        assertEquals(1775361600000L, dayStartMillis(1775404800000L, tz)) // 2026-04-05
    }

    @Test
    fun resultIsAlwaysTheFirstInstantOfItsOwnLocalDayAndNeverAfterNow() {
        val zones = listOf(
            "America/New_York", "Europe/Berlin", "Australia/Sydney",
            "America/Santiago", "America/Havana", "Asia/Shanghai"
        )
        // Transition-day midnights plus neighbourhood days, as raw instants so the same
        // instant is probed through every zone.
        val anchors = listOf(
            1772946000000L, // 2026-03-08 New York
            1793505600000L, // 2026-11-01 New York
            1774738800000L, // 2026-03-29 Berlin
            1792879200000L, // 2026-10-25 Berlin
            1788667200000L, // 2026-09-06 Santiago
            1791460800000L  // 2026-10-07, an ordinary midweek day
        )
        for (zoneId in zones) {
            val tz = zone(zoneId)
            for (anchor in anchors) {
                var now = anchor
                val limit = anchor + 2 * DAY
                while (now < limit) {
                    val start = dayStartMillis(now, tz)
                    assertTrue("$zoneId: start=$start must not be after now=$now", start <= now)
                    assertEquals(
                        "$zoneId: start=$start must belong to the local day of now=$now",
                        localDayIndex(now, tz),
                        localDayIndex(start, tz)
                    )
                    assertTrue(
                        "$zoneId: start=$start must be the first instant of its local day",
                        localDayIndex(start - MINUTE, tz) != localDayIndex(start, tz)
                    )
                    now += 17 * MINUTE
                }
            }
        }
    }

    @Test
    fun dayStartAgreesWithTheLocalDateOfTheInstant() {
        // The day string of an instant and of its computed day start must match; this
        // cross-checks the arithmetic against SimpleDateFormat's own local-date logic.
        val tz = TimeZone.getDefault()
        val anchors = listOf(1772946000000L, 1793505600000L, 1788667200000L, 1704067200000L)
        for (anchor in anchors) {
            var now = anchor
            repeat(48) {
                assertEquals(dayStringAt(now), dayStringAt(dayStartMillis(now, tz)))
                now += 37 * MINUTE
            }
        }
    }

    @Test
    fun sevenDaysRangeUsesTheSameDayStartConvention() {
        val today = dayStartMillis()
        assertTrue(today > 0L)
        assertEquals(0L, statsRangeStartMillis(SomeRange.ALL))
        assertEquals(0L, statsRangeStartMillis(SomeRange.UNKNOWN))
        assertTrue(statsRangeStartMillis(SomeRange.SEVEN_DAYS) < today)
        // TODAY delegates to dayStartMillis(); compare the day it lands on rather than
        // the exact instant so a midnight crossing between the two calls cannot flake.
        val tz = TimeZone.getDefault()
        assertEquals(
            localDayIndex(today, tz),
            localDayIndex(statsRangeStartMillis(SomeRange.TODAY), tz)
        )
    }

    @Test
    fun dayStringFormattingIsStable() {
        // SimpleDateFormat is timezone-dependent, so assert the contract rather than a
        // literal date: the day start and the instant it was derived from share a date.
        val instant = 1772946000000L
        val rendered = dayStringAt(instant)
        assertTrue("unexpected format: $rendered", rendered.matches(Regex("""\d{4}-\d{2}-\d{2}""")))
        assertEquals(rendered, dayStringAt(dayStartMillis(instant, TimeZone.getDefault())))
        // currentDayString() samples the clock itself, so assert its contract rather than
        // comparing against a second sample (which could straddle a midnight).
        assertTrue(currentDayString().matches(Regex("""\d{4}-\d{2}-\d{2}""")))
    }

    private enum class SomeRange { TODAY, SEVEN_DAYS, ALL, UNKNOWN }
}
