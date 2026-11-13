
def merge_intervals(rows, max_gap=3.0):
    intervals = []

    rows = sorted(rows, key=lambda x: x["start_time"])

    for row in rows:
        start = float(row["start_time"])
        end = float(row["end_time"])

        if not intervals or start - intervals[-1]["end"] > max_gap:
            intervals.append({
                "start": start,
                "end": end
            })
        else:
            intervals[-1]["end"] = max(
                intervals[-1]["end"],
                end
            )

    return intervals


def test_intervals():
    test_cases = [
        {
            "name": "Adjacent segments",
            "rows": [
                {"start_time": 0, "end_time": 3},
                {"start_time": 3, "end_time": 6},
                {"start_time": 6, "end_time": 9}
            ],
            "expected": [
                {"start": 0, "end": 9}
            ]
        },
        {
            "name": "Separate intervals",
            "rows": [
                {"start_time": 0, "end_time": 3},
                {"start_time": 9, "end_time": 12}
            ],
            "expected": [
                {"start": 0, "end": 3},
                {"start": 9, "end": 12}
            ]
        },
        {
            "name": "Maximum allowed gap",
            "rows": [
                {"start_time": 0, "end_time": 3},
                {"start_time": 6, "end_time": 9}
            ],
            "expected": [
                {"start": 0, "end": 9}
            ]
        },
        {
            "name": "Gap greater than maximum",
            "rows": [
                {"start_time": 0, "end_time": 3},
                {"start_time": 7, "end_time": 10}
            ],
            "expected": [
                {"start": 0, "end": 3},
                {"start": 7, "end": 10}
            ]
        },
        {
            "name": "Unsorted input",
            "rows": [
                {"start_time": 10, "end_time": 13},
                {"start_time": 0, "end_time": 3},
                {"start_time": 3, "end_time": 6}
            ],
            "expected": [
                {"start": 0, "end": 6},
                {"start": 10, "end": 13}
            ]
        },
        {
            "name": "Overlapping segments",
            "rows": [
                {"start_time": 0, "end_time": 4},
                {"start_time": 3, "end_time": 6}
            ],
            "expected": [
                {"start": 0, "end": 6}
            ]
        }
    ]

    for case in test_cases:
        result = merge_intervals(case["rows"])

        assert result == case["expected"], (
            f"\nFAILED: {case['name']}"
            f"\nExpected: {case['expected']}"
            f"\nGot: {result}"
        )

        print(f"PASSED: {case['name']}")

    print("\nAll tests passed!")


if __name__ == "__main__":
    test_intervals()
