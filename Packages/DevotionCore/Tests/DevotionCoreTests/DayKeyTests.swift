import XCTest
@testable import DevotionCore

final class DayKeyTests: XCTestCase {
    func testParsesValidDates() throws {
        let key = try XCTUnwrap(DayKey("2026-09-27"))
        XCTAssertEqual(key.year, 2026)
        XCTAssertEqual(key.month, 9)
        XCTAssertEqual(key.day, 27)
        XCTAssertEqual(key.string, "2026-09-27")
        XCTAssertNotNil(DayKey("2024-02-29"), "闰年 2 月 29 日")
    }

    func testRejectsInvalidDates() {
        for raw in ["2026-02-30", "2025-02-29", "2026-13-01", "2026-00-10", "2026-9-1", "abcd-ef-gh", "", "2026-09-27T00"] {
            XCTAssertNil(DayKey(raw), raw)
        }
    }

    func testEpochDayRoundTrip() {
        XCTAssertEqual(DayKey(year: 1970, month: 1, day: 1).epochDay, 0)
        XCTAssertEqual(DayKey(year: 2000, month: 3, day: 1).epochDay, 11_017)
        for epochDay in stride(from: -30_000, through: 60_000, by: 37) {
            XCTAssertEqual(DayKey(epochDay: epochDay).epochDay, epochDay)
        }
    }

    func testWeekday() {
        XCTAssertEqual(DayKey(year: 1970, month: 1, day: 1).weekday, 4) // 星期四
        XCTAssertEqual(DayKey(year: 2026, month: 9, day: 27).weekday, 0) // 主日
        XCTAssertEqual(DayKey(year: 1969, month: 12, day: 31).weekday, 3)
    }

    func testAddingAndDifference() throws {
        let key = try XCTUnwrap(DayKey("2024-02-28"))
        XCTAssertEqual(key.adding(days: 1).string, "2024-02-29")
        XCTAssertEqual(key.adding(days: 2).string, "2024-03-01")
        XCTAssertEqual(key.adding(days: -59).string, "2023-12-31")
        XCTAssertEqual(key.days(until: try XCTUnwrap(DayKey("2025-02-28"))), 366)
        XCTAssertEqual(key.days(until: key.adding(days: -3)), -3)
    }

    func testComparisonAndCodable() throws {
        let a = try XCTUnwrap(DayKey("2026-01-31"))
        let b = try XCTUnwrap(DayKey("2026-02-01"))
        XCTAssertLessThan(a, b)
        let data = try JSONEncoder().encode([a])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "[\"2026-01-31\"]")
        XCTAssertEqual(try JSONDecoder().decode([DayKey].self, from: data), [a])
        XCTAssertThrowsError(try JSONDecoder().decode([DayKey].self, from: Data("[\"2026-02-31\"]".utf8)))
    }

    func testFromDateUsesCalendarTimeZone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        // 2026-09-26 23:30 UTC = 2026-09-27 07:30 北京时间
        let date = Date(timeIntervalSince1970: 1_790_465_400)
        XCTAssertEqual(DayKey(date: date, calendar: calendar).string, "2026-09-27")
        XCTAssertEqual(DayKey(date: DayKey(year: 2026, month: 9, day: 27).date(calendar: calendar), calendar: calendar).string, "2026-09-27")
    }

    func testFormatting() throws {
        let key = try XCTUnwrap(DayKey("2026-09-27"))
        XCTAssertEqual(key.formatted(.chinese), "2026年9月27日 星期日")
        XCTAssertEqual(key.formatted(.chinese, weekday: false, year: false), "9月27日")
        XCTAssertEqual(key.formatted(.english), "Sunday, September 27, 2026")
        XCTAssertEqual(key.shortWeekday(.chinese), "周日")
        XCTAssertEqual(key.shortWeekday(.english), "Sun")
    }

    func testYearMonth() {
        let september = YearMonth(year: 2026, month: 9)
        XCTAssertEqual(september.numberOfDays, 30)
        XCTAssertEqual(YearMonth(year: 2024, month: 2).numberOfDays, 29)
        XCTAssertEqual(september.adding(months: 4), YearMonth(year: 2027, month: 1))
        XCTAssertEqual(september.adding(months: -9), YearMonth(year: 2025, month: 12))
        XCTAssertEqual(YearMonth(year: 2026, month: 1).adding(months: -13), YearMonth(year: 2024, month: 12))
        XCTAssertEqual(september.formatted(.chinese), "2026年9月")
        XCTAssertEqual(september.formatted(.english), "September 2026")

        // 2026 年 9 月 1 日是星期二：前面补 2 格，共 5 周
        let grid = september.calendarGrid
        XCTAssertEqual(grid.count, 35)
        XCTAssertNil(grid[0])
        XCTAssertNil(grid[1])
        XCTAssertEqual(grid[2]?.string, "2026-09-01")
        XCTAssertEqual(grid.compactMap { $0 }.count, 30)
    }
}
