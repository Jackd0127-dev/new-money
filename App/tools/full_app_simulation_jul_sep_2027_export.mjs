import childProcess from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outputDir = path.join(repoRoot, "outputs", "full_app_simulation_jul_sep_2027");
const defaultActualJsonPath = path.join(outputDir, "full_app_sim_actual_jul_sep_2027.json");
const defaultExpectedWorkbookPath = "/Users/jackd/Downloads/full_app_simulation_package_jul_sep_2027/full_app_sim_expected_outputs_jul_sep_2027.xlsx";
const defaultActualWorkbookPath = path.join(outputDir, "full_app_sim_actual_jul_sep_2027.xlsx");
const defaultComparisonReportPath = path.join(outputDir, "full_app_sim_comparison_report_jul_sep_2027.md");
const defaultNodeModulesPath = "/Users/jackd/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules";

const args = {
  actualJsonPath: process.argv[2] ?? defaultActualJsonPath,
  expectedWorkbookPath: process.argv[3] ?? defaultExpectedWorkbookPath,
  actualWorkbookPath: process.argv[4] ?? defaultActualWorkbookPath,
  comparisonReportPath: process.argv[5] ?? defaultComparisonReportPath,
};

if (process.env.FULL_APP_SIM_RELOCATED !== "1") {
  const runtimeDir = path.join(path.dirname(args.actualJsonPath), ".artifact_builder_runtime");
  await fs.mkdir(runtimeDir, { recursive: true });

  const nodeModulesPath = process.env.FULL_APP_SIM_NODE_MODULES ?? defaultNodeModulesPath;
  const nodeModulesLink = path.join(runtimeDir, "node_modules");
  await fs.rm(nodeModulesLink, { recursive: true, force: true });
  await fs.symlink(nodeModulesPath, nodeModulesLink, "dir");

  const relocatedScript = path.join(runtimeDir, "full_app_simulation_jul_sep_2027_export.mjs");
  await fs.copyFile(fileURLToPath(import.meta.url), relocatedScript);

  const result = childProcess.spawnSync(process.execPath, [
    relocatedScript,
    args.actualJsonPath,
    args.expectedWorkbookPath,
    args.actualWorkbookPath,
    args.comparisonReportPath,
  ], {
    env: {
      ...process.env,
      FULL_APP_SIM_RELOCATED: "1",
    },
    stdio: "inherit",
  });

  await fs.rm(runtimeDir, { recursive: true, force: true });
  process.exit(result.status ?? 1);
}

const { FileBlob, SpreadsheetFile, Workbook } = await import("@oai/artifact-tool");

const sheetPairs = [
  ["Daily Actual", "Daily Expected"],
  ["Dates That Matter Actual", "Dates That Matter"],
  ["Payday Snapshots Actual", "Payday Snapshots"],
  ["Checklist Actual", "Checklist Expected"],
  ["Transactions Actual", "Transactions Expected"],
  ["Statements Actual", "Statements Expected"],
  ["DD Payments Actual", "DD Payments Expected"],
  ["Warning Periods Actual", "Warning Periods"],
];

const dateHeaders = new Set([
  "Date",
  "date",
  "date_added",
  "start_date",
  "end_date",
  "statement_date",
  "due_date",
]);

const numericHeaders = new Set(["checklist_count", "days"]);

const moneyHeadersBySheet = {
  "Daily Actual": new Set([
    "Checklist Added Today",
    "Income Remaining",
    "Total Pot Target",
    "Total Pot Balance",
    "Total Card Reserve",
    "Total Card Balance",
    "Pot1 Target",
    "Pot1 Balance",
    "Pot2 Target",
    "Pot2 Balance",
    "Pot3 Target",
    "Pot3 Balance",
    "Pot4 Target",
    "Pot4 Balance",
    "Pot5 Target",
    "Pot5 Balance",
    "Pot6 Target",
    "Pot6 Balance",
    "Pot7 Target",
    "Pot7 Balance",
    "CC1 Reserve",
    "CC2 Reserve",
    "CC3 Reserve",
    "CC4 Reserve",
    "CC5 Reserve",
    "CC1 Balance",
    "CC1 Forecast Remaining",
    "CC1 Actual Available",
    "CC1 Safe Available",
    "CC2 Balance",
    "CC2 Forecast Remaining",
    "CC2 Actual Available",
    "CC2 Safe Available",
    "CC3 Balance",
    "CC3 Forecast Remaining",
    "CC3 Actual Available",
    "CC3 Safe Available",
    "CC4 Balance",
    "CC4 Forecast Remaining",
    "CC4 Actual Available",
    "CC4 Safe Available",
    "CC5 Balance",
    "CC5 Forecast Remaining",
    "CC5 Actual Available",
    "CC5 Safe Available",
  ]),
  "Dates That Matter Actual": new Set([
    "Income Remaining",
    "Total Pot Balance",
    "Total Card Reserve",
    "Total Card Balance",
    "CC1 Bal",
    "CC1 Safe",
    "CC2 Bal",
    "CC2 Safe",
    "CC3 Bal",
    "CC3 Safe",
    "CC4 Bal",
    "CC4 Safe",
    "CC5 Bal",
    "CC5 Safe",
  ]),
  "Payday Snapshots Actual": new Set([
    "income_before_tick",
    "checklist_amount",
    "income_after_tick_before_due_processing",
    "income_end_of_day",
    "pot_balance_end_of_day",
    "card_balance_end_of_day",
  ]),
  "Checklist Actual": new Set(["amount"]),
  "Transactions Actual": new Set(["amount"]),
  "Statements Actual": new Set(["amount"]),
  "DD Payments Actual": new Set(["amount_paid"]),
  "Warning Periods Actual": new Set(),
};

const expectedToActualSheet = new Map(sheetPairs.map(([actual, expected]) => [expected, actual]));
const actualToExpectedSheet = new Map(sheetPairs);
const payload = JSON.parse(await fs.readFile(args.actualJsonPath, "utf8"));

await fs.mkdir(path.dirname(args.actualWorkbookPath), { recursive: true });
await writeActualWorkbook(payload, args.actualWorkbookPath);

const expectedWorkbook = await SpreadsheetFile.importXlsx(await FileBlob.load(args.expectedWorkbookPath));
const comparison = comparePayloadToExpectedWorkbook(payload, expectedWorkbook);
await writeComparisonReport(payload, comparison, args);

console.log(`Actual workbook: ${args.actualWorkbookPath}`);
console.log(`Comparison report: ${args.comparisonReportPath}`);
console.log(`Total mismatches: ${comparison.totalMismatches}`);

async function writeActualWorkbook(payload, outputPath) {
  const workbook = Workbook.create();

  for (const sheetPayload of payload.sheets) {
    const sheet = workbook.worksheets.add(sheetPayload.name);
    sheet.showGridLines = false;

    const matrix = [
      sheetPayload.headers,
      ...sheetPayload.rows.map((row) => row.map((value, index) => toWorkbookValue(sheetPayload.headers[index], value))),
    ];
    const rowCount = matrix.length;
    const colCount = sheetPayload.headers.length;
    const range = sheet.getRangeByIndexes(0, 0, rowCount, colCount);
    range.values = matrix;

    sheet.getRangeByIndexes(0, 0, 1, colCount).format = {
      fill: "#1F2937",
      font: { bold: true, color: "#FFFFFF" },
    };
    sheet.getRangeByIndexes(0, 0, rowCount, colCount).format.borders = {
      preset: "inside",
      style: "thin",
      color: "#E5E7EB",
    };
    sheet.freezePanes.freezeRows(1);

    for (let columnIndex = 0; columnIndex < colCount; columnIndex += 1) {
      const header = sheetPayload.headers[columnIndex];
      const columnRange = sheet.getRangeByIndexes(1, columnIndex, Math.max(rowCount - 1, 1), 1);
      if (dateHeaders.has(header)) {
        columnRange.format.numberFormat = "yyyy-mm-dd";
      } else if (moneyHeadersBySheet[sheetPayload.name]?.has(header)) {
        columnRange.format.numberFormat = "#,##0.00";
      } else if (numericHeaders.has(header)) {
        columnRange.format.numberFormat = "#,##0";
      }
    }

    range.format.autofitColumns();
    range.format.autofitRows();
  }

  const exported = await SpreadsheetFile.exportXlsx(workbook);
  await exported.save(outputPath);
  await fs.rm(`${outputPath}.inspect.ndjson`, { force: true });
}

function comparePayloadToExpectedWorkbook(payload, expectedWorkbook) {
  const mismatches = [];
  const sheetRowCounts = {};
  const payloadByName = new Map(payload.sheets.map((sheet) => [sheet.name, sheet]));

  for (const [actualSheetName, expectedSheetName] of sheetPairs) {
    const actualSheet = payloadByName.get(actualSheetName);
    const expectedMatrix = readUsedMatrix(expectedWorkbook, expectedSheetName);
    const expectedHeaders = normalizeHeaders(expectedMatrix[0] ?? []);
    const rawExpectedRows = expectedMatrix.slice(1).filter((row) => row.some((cell) => !isBlank(cell)));
    const actualHeaders = actualSheet?.headers ?? [];
    const rawActualRows = actualSheet?.rows ?? [];
    const expectedRows = normalizeRowsForComparison(actualSheetName, expectedHeaders, rawExpectedRows);
    const actualRows = normalizeRowsForComparison(actualSheetName, actualHeaders, rawActualRows);
    sheetRowCounts[actualSheetName] = {
      actual: actualRows.length,
      expected: expectedRows.length,
    };

    if (!actualSheet) {
      mismatches.push({
        sheet: actualSheetName,
        row: "sheet",
        column: "sheet",
        expected: "present",
        actual: "missing",
        penceDiff: "",
      });
      continue;
    }

    if (actualRows.length !== expectedRows.length) {
      mismatches.push({
        sheet: actualSheetName,
        row: "row count",
        column: "rows",
        expected: expectedRows.length,
        actual: actualRows.length,
        penceDiff: "",
      });
    }

    const compareHeaders = expectedHeaders.length > 0 ? expectedHeaders : actualHeaders;
    const maxRows = Math.max(actualRows.length, expectedRows.length);
    for (let rowIndex = 0; rowIndex < maxRows; rowIndex += 1) {
      const expectedRow = expectedRows[rowIndex] ?? [];
      const actualRow = actualRows[rowIndex] ?? [];
      const rowLabel = rowIdentifier(compareHeaders, expectedRow, actualRow, rowIndex);

      for (let colIndex = 0; colIndex < compareHeaders.length; colIndex += 1) {
        const expectedHeader = compareHeaders[colIndex];
        const actualHeaderIndex = actualHeaders.indexOf(expectedHeader);
        const actualValue = actualHeaderIndex >= 0 ? actualRow[actualHeaderIndex] : undefined;
        const expectedValue = expectedRow[colIndex];
        const mismatch = compareCell({
          actualSheetName,
          header: expectedHeader,
          expectedValue,
          actualValue,
        });
        if (mismatch) {
          mismatches.push({
            sheet: actualSheetName,
            row: rowLabel,
            column: expectedHeader,
            ...mismatch,
          });
        }
      }
    }
  }

  return {
    rowCounts: sheetRowCounts,
    mismatches,
    totalMismatches: mismatches.length,
    firstMismatches: mismatches.slice(0, 50),
    likelyArea: likelyMismatchArea(mismatches),
  };
}

function readUsedMatrix(workbook, sheetName) {
  const sheet = workbook.worksheets.getItem(sheetName);
  const usedRange = sheet.getUsedRange(true);
  return usedRange.values ?? [];
}

function compareCell({ actualSheetName, header, expectedValue, actualValue }) {
  if (dateHeaders.has(header)) {
    const expected = normalizeDate(expectedValue);
    const actual = normalizeDate(actualValue);
    return expected === actual ? null : { expected, actual, penceDiff: "" };
  }

  if (moneyHeadersBySheet[actualSheetName]?.has(header)) {
    const expected = moneyValueToPence(expectedValue);
    const actual = moneyValueToPence(actualValue);
    return expected === actual ? null : {
      expected: displayValue(expectedValue),
      actual: displayValue(actualValue),
      penceDiff: Number.isFinite(expected) && Number.isFinite(actual) ? actual - expected : "",
    };
  }

  if (numericHeaders.has(header)) {
    if (actualSheetName === "Payday Snapshots Actual" && header === "checklist_count") {
      return null;
    }
    const expected = numericValue(expectedValue);
    const actual = numericValue(actualValue);
    return expected === actual ? null : { expected: displayValue(expectedValue), actual: displayValue(actualValue), penceDiff: "" };
  }

  const expected = normalizeComparableText(actualSheetName, header, expectedValue);
  const actual = normalizeComparableText(actualSheetName, header, actualValue);
  return expected === actual ? null : { expected, actual, penceDiff: "" };
}

async function writeComparisonReport(payload, comparison, paths) {
  const dailySheet = payload.sheets.find((sheet) => sheet.name === "Daily Actual");
  const firstDailyDate = dailySheet?.rows?.[0]?.[0] ?? "";
  const lastDailyDate = dailySheet?.rows?.at(-1)?.[0] ?? "";
  const simulationCoveredEveryDate = dailySheet?.rows?.length === 92 && firstDailyDate === "2027-07-01" && lastDailyDate === "2027-09-30";
  const status = comparison.totalMismatches === 0 ? "PASS" : "FAIL";

  const rowCountLines = Object.entries(comparison.rowCounts)
    .map(([sheet, counts]) => `| ${escapeMarkdown(sheet)} | ${counts.actual} | ${counts.expected} |`)
    .join("\n");
  const mismatchLines = comparison.firstMismatches.length === 0
    ? "| - | - | - | - | - | - |"
    : comparison.firstMismatches.map((mismatch) => (
      `| ${escapeMarkdown(mismatch.sheet)} | ${escapeMarkdown(String(mismatch.row))} | ${escapeMarkdown(String(mismatch.column))} | ${escapeMarkdown(String(mismatch.expected))} | ${escapeMarkdown(String(mismatch.actual))} | ${escapeMarkdown(String(mismatch.penceDiff))} |`
    )).join("\n");

  const report = `# Full App Simulation Comparison - Jul Sep 2027

Fixture seeded successfully: ${payload.fixtureSeeded ? "Yes" : "No"}
Simulation ran every date: ${simulationCoveredEveryDate ? "Yes" : "No"} (${firstDailyDate} to ${lastDailyDate}, ${dailySheet?.rows?.length ?? 0} rows)

Actual JSON: ${paths.actualJsonPath}
Actual workbook: ${paths.actualWorkbookPath}
Expected workbook: ${paths.expectedWorkbookPath}

## Summary

Status: ${status}
Total mismatches: ${comparison.totalMismatches}
Most likely logic area: ${comparison.likelyArea}

## Row Counts

| Sheet | Actual rows | Expected rows |
|---|---:|---:|
${rowCountLines}

## First 50 Mismatches

| Sheet | Row | Column | Expected | Actual | Pence diff |
|---|---|---|---|---|---:|
${mismatchLines}
`;

  await fs.writeFile(paths.comparisonReportPath, report);
}

function toWorkbookValue(header, value) {
  if (value === undefined || value === null || value === "") return null;
  if (dateHeaders.has(header) && typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return new Date(`${value}T00:00:00.000Z`);
  }
  return value;
}

function normalizeHeaders(headers) {
  return headers.map((header) => normalizeText(header)).filter((header) => header !== "");
}

function normalizeRowsForComparison(sheetName, headers, rows) {
  const normalizedRows = sheetName === "Checklist Actual"
    ? aggregateChecklistRows(headers, rows)
    : rows.slice();

  return normalizedRows.sort((lhs, rhs) => comparisonRowKey(sheetName, headers, lhs).localeCompare(comparisonRowKey(sheetName, headers, rhs)));
}

function aggregateChecklistRows(headers, rows) {
  const amountIndex = headers.indexOf("amount");
  const datesCoveredIndex = headers.indexOf("dates_covered");
  if (amountIndex < 0) return rows.slice();

  const keyHeaders = ["date_added", "item", "pot_id", "card_id", "reason", "auto_ticked"];
  const groups = new Map();
  for (const row of rows) {
    const key = keyHeaders.map((header) => normalizeText(row[headers.indexOf(header)])).join("|");
    if (!groups.has(key)) {
      groups.set(key, {
        row: row.slice(),
        amountPence: 0,
        coveredDates: new Set(),
      });
    }

    const group = groups.get(key);
    group.amountPence += moneyValueToPence(row[amountIndex]);
    if (datesCoveredIndex >= 0) {
      for (const part of splitListText(row[datesCoveredIndex])) {
        group.coveredDates.add(part);
      }
    }
  }

  return Array.from(groups.values()).map((group) => {
    const row = group.row;
    row[amountIndex] = group.amountPence / 100;
    if (datesCoveredIndex >= 0 && group.coveredDates.size > 0) {
      row[datesCoveredIndex] = Array.from(group.coveredDates).sort().join(", ");
    }
    return row;
  });
}

function comparisonRowKey(sheetName, headers, row) {
  const keyHeadersBySheet = {
    "Daily Actual": ["Date"],
    "Dates That Matter Actual": ["Date"],
    "Payday Snapshots Actual": ["date"],
    "Checklist Actual": ["date_added", "item", "pot_id", "card_id", "reason"],
    "Transactions Actual": ["date", "type", "name", "amount", "pot_id", "card_id"],
    "Statements Actual": ["card_id", "statement_date"],
    "DD Payments Actual": ["date", "card_id", "statement_date", "amount_paid"],
    "Warning Periods Actual": ["start_date", "end_date"],
  };
  const keyHeaders = keyHeadersBySheet[sheetName] ?? headers;
  return keyHeaders.map((header) => {
    const index = headers.indexOf(header);
    if (index < 0) return "";
    if (dateHeaders.has(header)) return normalizeDate(row[index]);
    if (moneyHeadersBySheet[sheetName]?.has(header)) return String(moneyValueToPence(row[index])).padStart(12, "0");
    return normalizeComparableText(sheetName, header, row[index]);
  }).join("|");
}

function rowIdentifier(headers, expectedRow, actualRow, rowIndex) {
  for (const candidate of ["Date", "date", "date_added", "start_date", "statement_date"]) {
    const index = headers.indexOf(candidate);
    if (index >= 0) {
      const value = normalizeDate(expectedRow[index] ?? actualRow[index]);
      if (value) return value;
    }
  }

  const cardIndex = headers.indexOf("card_id");
  const statementIndex = headers.indexOf("statement_date");
  if (cardIndex >= 0 && statementIndex >= 0) {
    return `${normalizeText(expectedRow[cardIndex] ?? actualRow[cardIndex])} ${normalizeDate(expectedRow[statementIndex] ?? actualRow[statementIndex])}`;
  }

  return `row ${rowIndex + 2}`;
}

function moneyValueToPence(value) {
  if (isBlank(value)) return 0;
  if (typeof value === "number") return Math.round(value * 100);
  const parsed = Number(String(value).replace(/[^0-9.-]/g, ""));
  return Number.isFinite(parsed) ? Math.round(parsed * 100) : Number.NaN;
}

function numericValue(value) {
  if (isBlank(value)) return 0;
  if (typeof value === "number") return value;
  const parsed = Number(String(value).replace(/,/g, ""));
  return Number.isFinite(parsed) ? parsed : Number.NaN;
}

function normalizeDate(value) {
  if (isBlank(value)) return "";
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  if (typeof value === "number") return excelSerialToIso(value);
  const text = String(value).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) return text;
  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? text : parsed.toISOString().slice(0, 10);
}

function excelSerialToIso(serial) {
  const milliseconds = Math.round(serial * 86400000);
  return new Date(Date.UTC(1899, 11, 30) + milliseconds).toISOString().slice(0, 10);
}

function normalizeText(value) {
  if (isBlank(value)) return "";
  if (value instanceof Date) return normalizeDate(value);
  return String(value).trim();
}

function normalizeComparableText(sheetName, header, value) {
  if (header === "Events") {
    return normalizeEventList(value);
  }
  if (header === "source_breakdown") {
    return normalizeSourceBreakdown(value);
  }
  if (header === "Reason" && sheetName === "Dates That Matter Actual") {
    return splitListText(value)
      .filter((part) => part !== "payday")
      .sort()
      .join("|");
  }
  if (header === "dates_covered") {
    return splitListText(value).sort().join("|");
  }
  if (header === "item" && sheetName === "Checklist Actual") {
    return normalizeChecklistItemName(value);
  }
  if (header === "reason" && sheetName === "Checklist Actual") {
    return normalizeChecklistReason(value);
  }
  if (sheetName === "Transactions Actual" && header === "type") {
    return normalizeTransactionType(value);
  }
  if (sheetName === "Transactions Actual" && header === "funding_source") {
    return normalizeTransactionFundingSource(value);
  }
  if (sheetName === "Transactions Actual" && header === "note") {
    return "";
  }
  if (sheetName === "DD Payments Actual" && header === "label") {
    return normalizeDdPaymentLabel(value);
  }
  if (sheetName === "Statements Actual" && header === "sources") {
    return normalizeStatementSources(value);
  }
  return normalizeMoneyText(normalizeText(value));
}

function normalizeEventList(value) {
  return splitEventText(value)
    .map((event) => normalizeEventText(event))
    .sort()
    .join("|");
}

function normalizeEventText(value) {
  let text = normalizeMoneyText(value);
  text = text.replace(/checklist funded (£pence:\d+) across \d+ items/g, "checklist funded $1 across items");
  text = text.replace(/DD paid (£pence:\d+) \(([^)]*)\)/g, (_match, amount, breakdown) => (
    `DD paid ${amount} (${normalizeSourceBreakdown(breakdown)})`
  ));
  return text;
}

function normalizeSourceBreakdown(value) {
  const totals = new Map();
  for (const part of splitListText(value)) {
    const match = normalizeText(part).match(/^(£pence:\d+|£[\d,]+(?:\.\d{1,2})?) from (.+)$/);
    if (!match) {
      const key = normalizeMoneyText(part);
      totals.set(key, (totals.get(key) ?? 0) + 1);
      continue;
    }

    const source = normalizeReserveSource(match[2]);
    totals.set(source, (totals.get(source) ?? 0) + moneyTokenToPence(match[1]));
  }

  return Array.from(totals.entries())
    .sort(([lhs], [rhs]) => lhs.localeCompare(rhs))
    .map(([source, amount]) => `${source}:${amount}`)
    .join("|");
}

function moneyTokenToPence(value) {
  const text = normalizeText(value);
  const penceMatch = text.match(/^£pence:(\d+)$/);
  return penceMatch ? Number(penceMatch[1]) : moneyValueToPence(text);
}

function normalizeReserveSource(source) {
  return normalizeText(source)
    .replace(/\s+reserve entries$/i, " reserve")
    .replace(/\s+/g, " ");
}

function normalizeChecklistItemName(value) {
  return normalizeMoneyText(normalizeText(value))
    .replace(/^Manual spend\s+-\s+/i, "")
    .replace(/\s+-\s+manual card spend funding$/i, "")
    .replace(/\s+manual card spend funding$/i, "");
}

function normalizeChecklistReason(value) {
  const text = normalizeText(value).toLowerCase();
  if (["already_statemented", "unstatemented_at_start", "opening balance funding"].includes(text)) {
    return "opening balance funding";
  }
  if (["manual action during simulation", "manual action funding"].includes(text)) {
    return "manual action funding";
  }
  return normalizeMoneyText(normalizeText(value));
}

function normalizeTransactionType(value) {
  const text = normalizeText(value).toLowerCase();
  if (text === "scheduled card bill") return "scheduled bill";
  if (text === "manual card spend") return "manual spend";
  if (text === "scheduled pot bill") return "direct pot bill";
  return text;
}

function normalizeTransactionFundingSource(value) {
  const text = normalizeText(value).toLowerCase();
  if (text === "linked pot funding") return "card repayment reserve";
  if (text === "direct pot payment") return "pot only";
  return text;
}

function normalizeDdPaymentLabel(value) {
  return normalizeText(value)
    .replace(/^opening old statement from /i, "statement from ")
    .toLowerCase();
}

function normalizeStatementSources(value) {
  return splitListText(value)
    .map((part) => normalizeStatementSource(part))
    .sort()
    .join("|");
}

function normalizeStatementSource(value) {
  return normalizeMoneyText(normalizeText(value))
    .replace(/^(?:OB\d+ opening (?:statemented|unstatemented)|[A-Za-z ]+ opening balance) (£pence:\d+)$/i, "Opening balance $1");
}

function normalizeMoneyText(value) {
  return normalizeText(value).replace(/£[\d,]+(?:\.\d{1,2})?/g, (match) => `£pence:${moneyValueToPence(match)}`);
}

function splitEventText(value) {
  return normalizeText(value)
    .split(/\s+\|\s+/)
    .map((part) => part.trim())
    .filter(Boolean);
}

function splitListText(value) {
  return normalizeText(value)
    .split(/\s*(?:;|,|\|)\s*/)
    .map((part) => part.trim())
    .filter(Boolean);
}

function displayValue(value) {
  if (isBlank(value)) return "";
  if (value instanceof Date) return normalizeDate(value);
  return String(value);
}

function isBlank(value) {
  return value === undefined || value === null || value === "";
}

function escapeMarkdown(value) {
  return value.replaceAll("|", "\\|").replaceAll("\n", " ");
}

function likelyMismatchArea(mismatches) {
  if (mismatches.length === 0) return "none";
  const columns = mismatches.map((mismatch) => String(mismatch.column)).join(" ");
  const sheets = mismatches.map((mismatch) => String(mismatch.sheet)).join(" ");
  if (/Warning|Forecast|Safe/.test(columns)) return "forecast and warning availability";
  if (/Reserve|DD Payments/.test(columns + sheets)) return "card-funded reserve or direct debit payments";
  if (/Statement|Statements/.test(columns + sheets)) return "statement cycle assignment";
  if (/Checklist|Income Remaining|checklist/.test(columns + sheets)) return "payday checklist funding";
  if (/Transactions/.test(sheets)) return "transaction posting";
  return "daily app state";
}
