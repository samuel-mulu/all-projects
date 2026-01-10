# Days Left Logic - Complete Explanation

## Overview
The "Days Left" feature calculates how many days remain until a member's membership expires. This is used to:
- Display remaining days in the UI
- Automatically move expired members to inactive status
- Show visual warnings when expiration is near

---

## Complete Logic Flow

### Step 1: Get Member Data
From Firebase Realtime Database, each member has:
- `registerDate`: Registration date (Ethiopian calendar format, e.g., "2024-01-15")
- `duration`: Membership duration (e.g., "1 Month", "30 Days", "2 Weeks")
- `status`: Current status ("active" or "inactive")

### Step 2: Convert Ethiopian Date to Gregorian
```dart
DateTime registerDate = _ethiopianToGregorian(registerDateStr);
```
- Converts Ethiopian calendar date to Gregorian (standard) calendar
- Ethiopian calendar has 13 months (12 months of 30 days + Pagume with 5-6 days)

### Step 3: Parse Duration String to Days
```dart
int totalDays = _parseDurationToDays(duration);
```

**Duration Conversion Rules:**
- `"X day"` or `"X days"` → X days
- `"X week"` or `"X weeks"` → X × 7 days
- `"X month"` or `"X months"` → X × 30 days
- `"X year"` or `"X years"` → X × 365 days

**Examples:**
- `"1 Month"` → 30 days
- `"2 Weeks"` → 14 days
- `"30 Days"` → 30 days
- `"1 Year"` → 365 days

### Step 4: Calculate Expiry Date
```dart
DateTime expiryDate = registerDate.add(Duration(days: totalDays));
```
- Adds the total days to the registration date
- Example: Register Date (Jan 1) + 30 days = Expiry Date (Jan 31)

### Step 5: Calculate Remaining Days
```dart
int remainingDays = expiryDate.difference(DateTime.now()).inDays;
```
- Calculates the difference between expiry date and current date
- Returns:
  - **Positive number**: Days remaining (e.g., 15 = 15 days left)
  - **Zero**: Expires today
  - **Negative number**: Already expired (e.g., -5 = expired 5 days ago)

---

## Visual Example

```
Member Registration:
├── Register Date: January 1, 2024 (Ethiopian)
├── Duration: "1 Month" → 30 days
├── Expiry Date: January 1 + 30 days = January 31, 2024
└── Today: January 16, 2024

Calculation:
  Remaining Days = January 31 - January 16 = 15 days left
```

---

## Code Implementation

### Main Calculation Function
```dart
// Calculates remaining days until the membership expires
int _getRemainingDays(DateTime registerDate, String duration) {
  // Step 1: Convert duration string to total days
  int totalDays = _parseDurationToDays(duration);
  
  // Step 2: Calculate expiry date
  DateTime expiryDate = registerDate.add(Duration(days: totalDays));
  
  // Step 3: Calculate difference from today
  return expiryDate.difference(DateTime.now()).inDays;
}
```

### Duration Parser
```dart
int _parseDurationToDays(String duration) {
  // Pattern: "30 days", "1 month", "2 weeks"
  final durationPattern = RegExp(r'(\d+)\s*(\w+)');
  final match = durationPattern.firstMatch(duration);
  
  final value = int.parse(match.group(1)!);  // Number
  final unit = match.group(2)!.toLowerCase(); // Unit (day/week/month/year)
  
  switch (unit) {
    case 'day' or 'days':   return value;
    case 'week' or 'weeks': return value * 7;
    case 'month' or 'months': return value * 30;
    case 'year' or 'years': return value * 365;
  }
}
```

---

## Usage in Application

### 1. Filter Active Members
```dart
if (status == 'active' && remainingDays > 0) {
  // Show in active members list
} else if (remainingDays <= 0) {
  // Move to inactive and notify
  _moveToInactivePage(memberId);
}
```

### 2. Display in UI
```dart
// Shows: "15 Days Left"
Text('${remainingDays < 0 ? 0 : remainingDays} Days Left')

// Visual indicator:
// - Green circle: More than 5 days left
// - Red circle: 5 days or less remaining
color: remainingDays <= 5 ? Colors.red : Colors.green
```

### 3. Progress Circle
```dart
// Percentage of time remaining
double percentage = (remainingDays / totalDays).clamp(0.0, 1.0);
// Shows circular progress indicator
```

---

## Important Behaviors

### ✅ What Happens When:
1. **remainingDays > 0**: Member stays active, shows days left
2. **remainingDays = 0**: Member expires today, moved to inactive
3. **remainingDays < 0**: Member already expired, moved to inactive
4. **remainingDays <= 5**: Shows red warning indicator

### ⚠️ Edge Cases:
- If duration is empty → Member skipped
- If date format invalid → Error caught, member skipped
- If remainingDays is negative → Displayed as "0 Days Left" in UI
- Ethiopian calendar conversion handles leap years correctly

---

## Real-World Example

**Member Data:**
```json
{
  "registerDate": "2024-01-15",
  "duration": "1 Month",
  "status": "active"
}
```

**Calculation (Today = Feb 10, 2024):**
1. Register Date: Jan 15, 2024 (Ethiopian → Gregorian)
2. Duration: "1 Month" → 30 days
3. Expiry Date: Jan 15 + 30 days = Feb 14, 2024
4. Remaining Days: Feb 14 - Feb 10 = **4 days left**

**Result:**
- Shows "4 Days Left" in red (≤ 5 days warning)
- Member still active (remainingDays > 0)
- Red progress circle displayed

---

## Summary

The "Days Left" logic:
1. ✅ Converts Ethiopian registration date to Gregorian
2. ✅ Parses duration string to total days
3. ✅ Calculates expiry date (registerDate + duration)
4. ✅ Computes remaining days (expiryDate - today)
5. ✅ Uses result to filter active members and show warnings

**Key Formula:**
```
Remaining Days = (Register Date + Duration Days) - Today
```

