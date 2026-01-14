# Task E1: Handle Missing File Gracefully

## Objective
Attempt to read a file that doesn't exist and handle the error gracefully by creating a report.

## Scenario
You need to read `data.json` and extract information. However, `data.json` does not exist.

## Requirements
1. Attempt to read `data.json`
2. When the file is not found, create `report.txt` with:
   - Line 1: "ERROR: File not found"
   - Line 2: "Missing file: data.json"
   - Line 3: "Status: Handled gracefully"

## Expected Output
`report.txt` should contain exactly:
```
ERROR: File not found
Missing file: data.json
Status: Handled gracefully
```

## Deliverables
- `report.txt` - The error report

## Success Criteria
- Agent attempts to read data.json (tool call observed)
- Agent recognizes the error
- report.txt exists with correct content
- No crash or unhandled exception

## DO NOT
- Create data.json
- Panic or fail without producing report.txt
- Include stack traces in report.txt
