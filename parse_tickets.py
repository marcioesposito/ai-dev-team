#!/usr/bin/env python3
"""
Parses the Jira REST API search response from stdin
and prints ticket keys one per line.

Usage:
    curl ... | python3 parse_tickets.py
"""
import sys
import json


def parse_tickets(data: dict) -> list[str]:
    issues = data.get("issues", [])
    return [issue["key"] for issue in issues]


def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"ERROR: Failed to parse Jira response as JSON: {e}", file=sys.stderr)
        sys.exit(1)

    if "errorMessages" in data:
        for msg in data["errorMessages"]:
            print(f"ERROR: Jira API error: {msg}", file=sys.stderr)
        sys.exit(1)

    keys = parse_tickets(data)
    if keys:
        print("\n".join(keys))


if __name__ == "__main__":
    main()