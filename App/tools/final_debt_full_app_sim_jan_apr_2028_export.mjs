import childProcess from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outputDir = path.join(repoRoot, "outputs", "final_debt_full_app_simulation_jan_apr_2028");
const defaultInputWorkbookPath = "/Users/jackd/Downloads/final_debt_full_app_sim_package_jan_apr_2028/final_debt_full_app_sim_input_jan_apr_2028.xlsx";
const defaultExpectedWorkbookPath = "/Users/jackd/Downloads/final_debt_full_app_sim_package_jan_apr_2028/final_debt_full_app_sim_expected_jan_apr_2028.xlsx";
const defaultActualJsonPath = path.join(outputDir, "final_debt_full_app_sim_actual_jan_apr_2028.json");
const defaultActualWorkbookPath = path.join(outputDir, "final_debt_full_app_sim_actual_jan_apr_2028.xlsx");
const defaultComparisonReportPath = path.join(outputDir, "final_debt_full_app_sim_mismatch_report_jan_apr_2028.md");
const defaultNodeModulesPath = "/Users/jackd/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules";

const args = {
  inputWorkbookPath: process.argv[2] ?? defaultInputWorkbookPath,
  expectedWorkbookPath: process.argv[3] ?? defaultExpectedWorkbookPath,
  actualJsonPath: process.argv[4] ?? defaultActualJsonPath,
  actualWorkbookPath: process.argv[5] ?? defaultActualWorkbookPath,
  comparisonReportPath: process.argv[6] ?? defaultComparisonReportPath,
};

if (process.env.FINAL_DEBT_SIM_RELOCATED !== "1") {
  const runtimeDir = path.join(path.dirname(args.actualJsonPath), ".artifact_builder_runtime");
  await fs.mkdir(runtimeDir, { recursive: true });

  const nodeModulesPath = process.env.FINAL_DEBT_SIM_NODE_MODULES ?? defaultNodeModulesPath;
  const nodeModulesLink = path.join(runtimeDir, "node_modules");
  await fs.rm(nodeModulesLink, { recursive: true, force: true });
  await fs.symlink(nodeModulesPath, nodeModulesLink, "dir");

  const relocatedScript = path.join(runtimeDir, "final_debt_full_app_sim_jan_apr_2028_export.mjs");
  await fs.copyFile(fileURLToPath(import.meta.url), relocatedScript);

  const result = childProcess.spawnSync(process.execPath, [
    relocatedScript,
    args.inputWorkbookPath,
    args.expectedWorkbookPath,
    args.actualJsonPath,
    args.actualWorkbookPath,
    args.comparisonReportPath,
  ], {
    env: {
      ...process.env,
      FINAL_DEBT_SIM_RELOCATED: "1",
    },
    stdio: "inherit",
  });

  await fs.rm(runtimeDir, { recursive: true, force: true });
  process.exit(result.status ?? 1);
}

const { FileBlob, SpreadsheetFile, Workbook } = await import("@oai/artifact-tool");

const startDate = "2028-01-01";
const endDate = "2028-04-30";
const cardOrder = ["CC1", "CC2", "CC3", "CC4", "CC5"];
const potOrder = ["Pot1", "Pot2", "Pot3", "Pot4", "Pot5", "Pot6", "Pot7", "Pot8"];
const debtOrder = ["D1", "D2", "D3", "D4", "D5"];

const dailyHeaders = [
  "Date", "Day", "Events", "Income Added Today", "Available Money", "Checklist Added Today",
  "Checklist Items Today", "Scheduled Bills Due Today", "Manual Actions Today", "Debt Interest Today",
  "Debt Payments Today", "Card DD Paid Today", "Statements Created Today", "Total Pot Target",
  "Total Pot Balance", "Total Card Reserve", "Total Card Balance", "Total Debt Balance",
  "Total Debt Interest Accrued", "Warning",
  ...potOrder.flatMap((potId) => [`${potId} Target`, `${potId} Balance`]),
  ...cardOrder.flatMap((cardId) => [`${cardId} Reserve`, `${cardId} Balance`, `${cardId} Forecast Remaining`, `${cardId} Actual Available`, `${cardId} Safe Available`]),
  ...debtOrder.flatMap((debtId) => [`${debtId} Balance`, `${debtId} Interest Today`, `${debtId} Interest Total`, `${debtId} Paid Total`, `${debtId} Next Due`, `${debtId} Next Amount`, `${debtId} Status`]),
];

const sheetPairs = [
  ["Daily Actual", "Daily Expected"],
  ["Priority UI Actual", "Priority UI Expected"],
  ["Income Actual", "Income Expected"],
  ["Checklist Actual", "Checklist Expected"],
  ["Transactions Actual", "Transactions Expected"],
  ["Debt Schedule Actual", "Debt Schedule Expected"],
  ["Debt Payments Actual", "Debt Payments Expected"],
  ["Debt Snapshots Actual", "Debt Snapshots Expected"],
  ["Statements Actual", "Statements Expected"],
  ["Card DD Actual", "Card DD Expected"],
  ["Manual Actions Actual", "Manual Actions Expected"],
  ["Warning Periods Actual", "Warning Periods"],
];

const dateHeaders = new Set(["Date", "date", "due_date", "statement_date", "start_date", "end_date", "next_due"]);
const integerHeaders = new Set(["Checklist Items Today", "days"]);
const moneyHeaderPatterns = [
  /amount/i, /money/i, /income/i, /balance/i, /interest/i, /payment/i, /paid/i,
  /target/i, /reserve/i, /available/i, /forecast/i, /manual actions today/i,
  /scheduled bills due today/i, /card dd/i, /statements created today/i,
];

await fs.mkdir(outputDir, { recursive: true });
const inputWorkbook = await SpreadsheetFile.importXlsx(await FileBlob.load(args.inputWorkbookPath));
const expectedWorkbook = await SpreadsheetFile.importXlsx(await FileBlob.load(args.expectedWorkbookPath));
const input = readScenario(inputWorkbook);
const payload = simulate(input);
const comparison = comparePayloadToExpectedWorkbook(payload, expectedWorkbook);
await writeActualWorkbook(payload, comparison, args.actualWorkbookPath);
await writeComparisonReport(payload, comparison, args);
await fs.writeFile(args.actualJsonPath, JSON.stringify({
  ...payload,
  comparison: {
    rowCounts: comparison.rowCounts,
    totalMismatches: comparison.totalMismatches,
    firstMismatches: comparison.firstMismatches,
    likelyArea: comparison.likelyArea,
  },
}, null, 2));

console.log(`Actual JSON: ${args.actualJsonPath}`);
console.log(`Actual workbook: ${args.actualWorkbookPath}`);
console.log(`Comparison report: ${args.comparisonReportPath}`);
console.log(`Total mismatches: ${comparison.totalMismatches}`);

function readScenario(workbook) {
  const incomeRows = readObjects(workbook, "Income Streams").map((row, index) => ({
    id: text(row.income_id),
    name: text(row.name),
    amountPence: moneyToPence(row.amount),
    frequency: text(row.frequency),
    day: row.day == null || row.day === "" ? null : Number(row.day),
    startDate: iso(row.start_date),
    endDate: iso(row.end_date),
    explicitDates: splitList(row.explicit_dates).map(iso),
    order: index,
  }));
  const cards = readObjects(workbook, "Credit Cards").map((row) => ({
    id: text(row.card_id),
    name: text(row.card_name),
    dueDay: Number(row.due_day),
    statementDay: Number(row.statement_day),
    limitPence: moneyToPence(row.limit),
    linkedPotId: text(row.linked_pot_id),
  }));
  const pots = readObjects(workbook, "Pots").map((row) => ({
    id: text(row.pot_id),
    name: text(row.pot_name),
    linkedCardId: text(row.linked_card_id),
    type: text(row.pot_type),
  }));
  const openingBalances = readObjects(workbook, "Opening Balances").map((row, index) => ({
    id: text(row.opening_balance_id),
    cardId: text(row.card_id),
    amountPence: moneyToPence(row.amount),
    potId: text(row.funding_pot_id),
    status: text(row.status),
    statementDate: iso(row.statement_date),
    dueDate: iso(row.due_date),
    note: text(row.notes),
    order: index,
    funded: false,
    paid: false,
  }));
  const bills = readObjects(workbook, "Scheduled Bills").map((row, index) => ({
    id: text(row.bill_id),
    name: text(row.bill_name),
    amountPence: moneyToPence(row.amount),
    frequency: text(row.frequency),
    dueDay: row.due_day == null || row.due_day === "" ? null : Number(row.due_day),
    startDate: iso(row.start_date),
    endDate: iso(row.end_date),
    potId: text(row.pot_id),
    cardId: text(row.card_id),
    note: text(row.notes),
    order: index,
  }));
  const debts = readObjects(workbook, "Debts").map((row, index) => ({
    id: text(row.debt_id),
    name: text(row.name),
    type: text(row.type),
    strategy: text(row.strategy),
    currentBalancePence: moneyToPence(row.current_balance),
    minimumPaymentPence: moneyToPence(row.minimum_payment),
    extraOrFixedPaymentPence: moneyToPence(row.extra_or_fixed_payment),
    aprBasisPoints: Math.round(Number(row.apr_percent ?? 0) * 100),
    dueDate: iso(row.due_date),
    linkedPotId: text(row.linked_pot_id),
    paymentFrequency: text(row.payment_frequency),
    paymentDay: row.payment_day == null || row.payment_day === "" ? null : Number(row.payment_day),
    paymentStartDate: iso(row.payment_start_date),
    note: text(row.notes),
    order: index,
  }));
  const manualActions = readObjects(workbook, "Manual Actions To Run").map((row, index) => ({
    id: text(row.action_id),
    date: iso(row.date),
    type: text(row.action_type),
    name: text(row.name),
    amountPence: moneyToPence(row.amount),
    potId: text(row.pot_id),
    cardId: text(row.card_id),
    debtId: text(row.debt_id),
    recalculationMode: text(row.recalculation_mode),
    note: text(row.notes),
    order: index,
  }));
  const priorityDates = readObjects(workbook, "Priority Test Days").map((row) => iso(row.date)).filter(Boolean);
  return {
    incomeRows,
    cards,
    pots,
    openingBalances,
    bills,
    debts,
    manualActions,
    priorityDates,
  };
}

function simulate(input) {
  const incomeEvents = buildIncomeEvents(input.incomeRows);
  const incomeEventByDate = new Map(incomeEvents.map((event) => [event.date, event]));
  const incomeWindows = incomeEvents.map((event, index) => ({
    ...event,
    endDate: index + 1 < incomeEvents.length ? addDays(incomeEvents[index + 1].date, -1) : endDate,
  }));
  const incomeWindowByDate = new Map(incomeWindows.map((window) => [window.date, window]));
  const billOccurrences = buildBillOccurrences(input.bills);
  const billOccurrenceByKey = new Map(billOccurrences.map((occurrence) => [occurrence.key, occurrence]));
  const debtSchedules = buildDebtSchedules(input.debts);
  const debtScheduleById = new Map(debtSchedules.map((item) => [item.id, item]));
  const debtScheduleByDate = groupBy(debtSchedules, (item) => item.dueDate);
  const manualByDate = groupBy(input.manualActions, (action) => action.date);
  const billByDate = groupBy(billOccurrences, (occurrence) => occurrence.dueDate);
  const statementSourceMap = new Map();
  const statementRecords = new Map();

  const pots = new Map(input.pots.map((pot) => [pot.id, { ...pot, targetPence: 0, balancePence: 0 }]));
  const cards = new Map(input.cards.map((card) => [card.id, { ...card, balancePence: 0, reserveEntries: [] }]));
  const debts = new Map(input.debts.map((debt) => [debt.id, {
    ...debt,
    balancePence: debt.currentBalancePence,
    interestTodayPence: 0,
    interestTotalPence: 0,
    paidTotalPence: 0,
    status: initialDebtStatus(debt),
  }]));

  const sheets = {
    dailyRows: [],
    priorityRows: [],
    incomeRows: [],
    checklistRows: [],
    transactionRows: [],
    debtScheduleRows: [],
    debtPaymentRows: [],
    debtSnapshotRows: [],
    statementRows: [],
    cardDdRows: [],
    manualActionRows: [],
    warningRows: [],
  };
  const dailySummaries = [];

  for (const opening of input.openingBalances) {
    cards.get(opening.cardId).balancePence += opening.amountPence;
    sheets.transactionRows.push([
      startDate, "opening_balance", `${opening.cardId} ${opening.id}`, pounds(opening.amountPence), opening.potId, opening.cardId,
      opening.statementDate, opening.dueDate, "opening_balance", opening.note,
    ]);
    addStatementSource(statementSourceMap, opening.cardId, opening.statementDate, {
      date: startDate,
      name: opening.id,
      amountPence: opening.amountPence,
      kind: "opening",
      potId: opening.potId,
      openingId: opening.id,
      order: opening.order,
      sourceText: opening.status === "already_statemented" ? `${opening.id} opening statement` : `${opening.id} ${formatPounds(opening.amountPence)}`,
    });
    if (opening.status === "already_statemented") {
      statementRecords.set(statementKey(opening.cardId, opening.statementDate), {
        cardId: opening.cardId,
        statementDate: opening.statementDate,
        dueDate: opening.dueDate,
        amountPence: opening.amountPence,
        sources: [`${opening.id} opening statement`],
        status: "created_before_run",
        created: true,
        paid: false,
      });
    }
  }

  let availablePence = 0;
  let activeWarning = "";
  let warningStart = null;
  let previousDate = null;

  for (let date = startDate; date <= endDate; date = addDays(date, 1)) {
    const events = [];
    let checklistAddedPence = 0;
    let checklistItemsToday = 0;
    let scheduledBillsDueTodayPence = 0;
    let manualActionsTodayPence = 0;
    let debtInterestTodayPence = 0;
    let debtPaymentsTodayPence = 0;
    let cardDdPaidTodayPence = 0;
    let statementsCreatedTodayPence = 0;

    for (const debt of debtOrder.map((id) => debts.get(id)).filter(Boolean)) {
      debt.interestTodayPence = 0;
      if (debt.balancePence > 0 && debt.aprBasisPoints > 0) {
        const interest = dailyInterestPence(debt.balancePence, debt.aprBasisPoints);
        debt.balancePence += interest;
        debt.interestTodayPence = interest;
        debt.interestTotalPence += interest;
        debtInterestTodayPence += interest;
      }
    }

    const incomeEvent = incomeEventByDate.get(date);
    if (incomeEvent) {
      availablePence += incomeEvent.amountPence;
      sheets.incomeRows.push([date, incomeEvent.incomeIds.join(", "), pounds(incomeEvent.amountPence)]);
      const window = incomeWindowByDate.get(date);
      const funded = fundIncomeWindow({
        date,
        window,
        input,
        billOccurrences,
        debtSchedules,
        debts,
        pots,
        availablePence,
        checklistRows: sheets.checklistRows,
      });
      availablePence = funded.availablePence;
      checklistAddedPence += funded.amountPence;
      checklistItemsToday += funded.count;
      events.push(`Income ${formatPounds(incomeEvent.amountPence)}; funded ${formatPounds(funded.amountPence)} for window ${window.date} to ${window.endDate}`);
    }

    for (const occurrence of (billByDate.get(date) ?? []).sort(sortBillOccurrences)) {
      scheduledBillsDueTodayPence += occurrence.amountPence;
      const pot = pots.get(occurrence.potId);
      pot.targetPence -= occurrence.amountPence;
      pot.balancePence -= occurrence.amountPence;

      if (occurrence.cardId) {
        const card = cards.get(occurrence.cardId);
        const statementDate = statementDateForCharge(card, date);
        const dueDate = dueDateForStatement(card, statementDate);
        card.balancePence += occurrence.amountPence;
        card.reserveEntries.push({
          amountPence: occurrence.amountPence,
          remainingPence: occurrence.amountPence,
          statementDate,
          name: occurrence.name,
          order: occurrence.order,
          kind: "reserve",
        });
        addStatementSource(statementSourceMap, occurrence.cardId, statementDate, {
          date,
          name: occurrence.name,
          amountPence: occurrence.amountPence,
          kind: "reserve",
          cardId: occurrence.cardId,
          order: occurrence.order,
          sourceText: `${occurrence.name} ${formatPounds(occurrence.amountPence)}`,
        });
        sheets.transactionRows.push([date, "scheduled_bill", occurrence.name, pounds(occurrence.amountPence), occurrence.potId, occurrence.cardId, statementDate, dueDate, "card_reserve", occurrence.note]);
        events.push(`${occurrence.name} ${formatPounds(occurrence.amountPence)} to ${occurrence.cardId}; stmt ${statementDate} due ${dueDate}`);
      } else {
        sheets.transactionRows.push([date, "direct_pot_bill", occurrence.name, pounds(occurrence.amountPence), occurrence.potId, null, null, null, "pot_only", occurrence.note]);
        events.push(`${occurrence.name} ${formatPounds(occurrence.amountPence)} pot-only from ${occurrence.potId}`);
      }
      occurrence.processed = true;
    }

    for (const schedule of (debtScheduleByDate.get(date) ?? []).sort((a, b) => a.id.localeCompare(b.id))) {
      const debt = debts.get(schedule.debtId);
      if (!debt || debt.balancePence <= 0 || schedule.paid) continue;
      const processedPence = Math.min(schedule.plannedAmountPence, debt.balancePence);
      const pot = pots.get("Pot6");
      pot.targetPence -= processedPence;
      pot.balancePence -= processedPence;
      debt.balancePence = Math.max(0, debt.balancePence - processedPence);
      debt.paidTotalPence += processedPence;
      debtPaymentsTodayPence += processedPence;
      schedule.paid = true;
      schedule.status = "paid";
      sheets.debtPaymentRows.push([date, schedule.debtId, pounds(processedPence), pounds(processedPence), 0, "Pot6", "scheduled", schedule.id, pounds(debt.balancePence), debtPaymentNote(debt)]);
      events.push(`Debt ${schedule.debtId} scheduled payment ${formatPounds(processedPence)} paid`);
    }

    for (const action of (manualByDate.get(date) ?? []).sort((a, b) => a.order - b.order)) {
      if (action.type === "manual_card_spend") {
        checklistAddedPence += action.amountPence;
        checklistItemsToday += 1;
        manualActionsTodayPence += action.amountPence;
        availablePence -= action.amountPence;
        const pot = pots.get(action.potId);
        pot.targetPence += action.amountPence;
        pot.balancePence += action.amountPence;
        sheets.checklistRows.push([date, `Manual card spend ${action.name}`, pounds(action.amountPence), action.potId, action.cardId, null, "manual_card_spend", action.id, "Yes", action.note]);
        pot.targetPence -= action.amountPence;
        pot.balancePence -= action.amountPence;

        const card = cards.get(action.cardId);
        const statementDate = statementDateForCharge(card, date);
        const dueDate = dueDateForStatement(card, statementDate);
        card.balancePence += action.amountPence;
        card.reserveEntries.push({
          amountPence: action.amountPence,
          remainingPence: action.amountPence,
          statementDate,
          name: action.name,
          order: 10_000 + action.order,
          kind: "reserve",
        });
        addStatementSource(statementSourceMap, action.cardId, statementDate, {
          date,
          name: action.name,
          amountPence: action.amountPence,
          kind: "reserve",
          cardId: action.cardId,
          order: 10_000 + action.order,
          sourceText: `${action.name} ${formatPounds(action.amountPence)}`,
        });
        sheets.transactionRows.push([date, "manual_card_spend", action.name, pounds(action.amountPence), action.potId, action.cardId, statementDate, dueDate, "card_reserve", action.note]);
        sheets.manualActionRows.push([date, action.id, action.type, pounds(action.amountPence), pounds(action.amountPence), 0, "processed", action.note]);
        events.push(`Manual card ${action.name} ${formatPounds(action.amountPence)} on ${action.cardId}; stmt ${statementDate} due ${dueDate}`);
      } else if (action.type === "manual_debt_set_aside") {
        checklistAddedPence += action.amountPence;
        checklistItemsToday += 1;
        manualActionsTodayPence += action.amountPence;
        availablePence -= action.amountPence;
        const pot = pots.get(action.potId);
        pot.targetPence += action.amountPence;
        pot.balancePence += action.amountPence;
        sheets.checklistRows.push([date, `Set aside for debt ${action.name}`, pounds(action.amountPence), action.potId, null, action.debtId, "manual_debt_set_aside", action.id, "Yes", action.note]);
        sheets.manualActionRows.push([date, action.id, action.type, pounds(action.amountPence), pounds(action.amountPence), 0, "set_aside", action.note]);
        events.push(`Manual debt set-aside ${action.name} ${formatPounds(action.amountPence)}`);
      } else if (action.type === "manual_debt_payment_now") {
        const debt = debts.get(action.debtId);
        const processedPence = Math.min(action.amountPence, Math.max(0, debt?.balancePence ?? 0));
        const excessPence = Math.max(0, action.amountPence - processedPence);
        checklistAddedPence += processedPence;
        checklistItemsToday += 1;
        manualActionsTodayPence += processedPence;
        availablePence -= processedPence;
        const pot = pots.get(action.potId);
        pot.targetPence += processedPence;
        pot.balancePence += processedPence;
        sheets.checklistRows.push([date, `Manual debt payment ${action.name}`, pounds(processedPence), action.potId, null, action.debtId, "manual_debt_payment_now", action.id, "Yes", action.note]);
        pot.targetPence -= processedPence;
        pot.balancePence -= processedPence;
        if (debt) {
          debt.balancePence = Math.max(0, debt.balancePence - processedPence);
          debt.paidTotalPence += processedPence;
        }
        debtPaymentsTodayPence += processedPence;
        sheets.debtPaymentRows.push([date, action.debtId, pounds(processedPence), pounds(processedPence), 0, action.potId, "manualPayNow", action.id, pounds(debt?.balancePence ?? 0), action.note]);
        sheets.manualActionRows.push([date, action.id, action.type, pounds(action.amountPence), pounds(processedPence), pounds(excessPence), excessPence > 0 ? "processed_capped" : "processed", action.note]);
        events.push(`Manual debt ${action.name} requested ${formatPounds(action.amountPence)} processed ${formatPounds(processedPence)} excess ${formatPounds(excessPence)}`);
      }
    }

    for (const cardId of cardOrder) {
      const card = cards.get(cardId);
      const statementDate = dateForDay(date, card.statementDay);
      if (statementDate !== date) continue;
      const sources = getStatementSources(statementSourceMap, cardId, statementDate);
      const amountPence = sources.reduce((total, source) => total + source.amountPence, 0);
      if (amountPence <= 0) continue;
      const dueDate = dueDateForStatement(card, statementDate);
      const record = {
        cardId,
        statementDate,
        dueDate,
        amountPence,
        sources: sources.map((source) => source.sourceText),
        status: statementStatus(statementDate),
        created: true,
        paid: false,
      };
      statementRecords.set(statementKey(cardId, statementDate), record);
      statementsCreatedTodayPence += amountPence;
      events.push(`${cardId} statement ${formatPounds(amountPence)} due ${dueDate}`);
    }

    const dueStatements = Array.from(statementRecords.values())
      .filter((statement) => !statement.paid && statement.dueDate === date && statement.amountPence > 0)
      .sort((a, b) => a.cardId === b.cardId ? a.statementDate.localeCompare(b.statementDate) : a.cardId.localeCompare(b.cardId));
    for (const statement of dueStatements) {
      const card = cards.get(statement.cardId);
      const breakdownParts = [];
      const sources = getStatementSources(statementSourceMap, statement.cardId, statement.statementDate);
      for (const source of sources) {
        if (source.kind === "opening") {
          const opening = input.openingBalances.find((candidate) => candidate.id === source.openingId);
          if (opening?.funded) {
            const pot = pots.get(source.potId);
            pot.targetPence -= source.amountPence;
            pot.balancePence -= source.amountPence;
          }
          if (opening) opening.paid = true;
          breakdownParts.push(`${formatPounds(source.amountPence)} from ${source.potId}`);
        } else {
          const reserveEntry = card.reserveEntries.find((entry) => entry.statementDate === statement.statementDate && entry.name === source.name && entry.remainingPence > 0);
          const contributionPence = Math.min(source.amountPence, reserveEntry?.remainingPence ?? source.amountPence);
          if (reserveEntry) reserveEntry.remainingPence -= contributionPence;
          breakdownParts.push(`${formatPounds(contributionPence)} from ${statement.cardId} reserve`);
        }
      }
      card.balancePence = Math.max(0, card.balancePence - statement.amountPence);
      statement.paid = true;
      cardDdPaidTodayPence += statement.amountPence;
      const openingOnly = sources.length === 1 && sources[0].kind === "opening" && statement.statementDate < startDate;
      const label = openingOnly ? `opening statement ${sources[0].openingId}` : `statement ${statement.statementDate}`;
      sheets.cardDdRows.push([date, statement.cardId, statement.statementDate, pounds(statement.amountPence), breakdownParts.join("; "), label]);
      events.push(`${statement.cardId} DD ${formatPounds(statement.amountPence)} paid (${breakdownParts.join("; ")})`);
    }

    const cardAvailability = buildCardAvailability(cards, billOccurrences, date, incomeWindows);
    for (const debt of debts.values()) {
      debt.status = debtStatus(debt);
    }
    const warning = warningText(cards, cardAvailability, debts);
    if (warning !== activeWarning) {
      if (activeWarning && warningStart && previousDate) {
        sheets.warningRows.push([warningStart, previousDate, daysInclusive(warningStart, previousDate), activeWarning]);
      }
      activeWarning = warning;
      warningStart = warning ? date : null;
    }
    previousDate = date;

    for (const debtId of debtOrder) {
      const debt = debts.get(debtId);
      const next = nextDebtSchedule(debtSchedules, debtId, date);
      sheets.debtSnapshotRows.push([
        date, debtId, pounds(debt.balancePence), pounds(debt.interestTodayPence), pounds(debt.interestTotalPence),
        pounds(debt.paidTotalPence), next?.dueDate ?? null, pounds(next?.plannedAmountPence ?? 0), debt.status,
      ]);
    }

    const dailyRow = makeDailyRow({
      date,
      events,
      incomeAddedPence: incomeEvent?.amountPence ?? 0,
      availablePence,
      checklistAddedPence,
      checklistItemsToday,
      scheduledBillsDueTodayPence,
      manualActionsTodayPence,
      debtInterestTodayPence,
      debtPaymentsTodayPence,
      cardDdPaidTodayPence,
      statementsCreatedTodayPence,
      pots,
      cards,
      debts,
      debtSchedules,
      cardAvailability,
      warning,
    });
    sheets.dailyRows.push(dailyRow);
    dailySummaries.push({
      date,
      events: events.join(" | "),
      warning,
      dailyRow,
      cardAvailability,
      cardTiles: buildCardTiles(cards, cardAvailability),
      debtTiles: buildDebtTiles(debts, debtSchedules, date),
      potTiles: buildPotTiles(pots),
    });
  }

  if (activeWarning && warningStart && previousDate) {
    sheets.warningRows.push([warningStart, previousDate, daysInclusive(warningStart, previousDate), activeWarning]);
  }

  for (const [key, sources] of statementSourceMap.entries()) {
    if (statementRecords.has(key)) continue;
    const [cardId, statementDate] = key.split("|");
    const amountPence = sources.reduce((total, source) => total + source.amountPence, 0);
    if (amountPence <= 0) continue;
    const card = cards.get(cardId);
    statementRecords.set(key, {
      cardId,
      statementDate,
      dueDate: dueDateForStatement(card, statementDate),
      amountPence,
      sources: sources.sort((a, b) => a.date.localeCompare(b.date) || a.order - b.order).map((source) => source.sourceText),
      status: statementStatus(statementDate),
      created: statementDate <= endDate,
      paid: false,
    });
  }

  for (const statement of Array.from(statementRecords.values()).sort(sortStatements)) {
    sheets.statementRows.push([
      statement.cardId,
      statement.statementDate,
      statement.dueDate,
      pounds(statement.amountPence),
      statement.status,
      statement.sources.join("; "),
    ]);
  }
  for (const schedule of debtSchedules) {
    sheets.debtScheduleRows.push([schedule.id, schedule.debtId, schedule.dueDate, pounds(schedule.plannedAmountPence), schedule.status ?? "planned"]);
  }
  sheets.priorityRows = buildPriorityRows(input.priorityDates, dailySummaries);

  return {
    generatedAt: new Date().toISOString(),
    fixtureSeeded: true,
    startDate,
    endDate,
    inputWorkbookPath: args.inputWorkbookPath,
    expectedWorkbookPath: args.expectedWorkbookPath,
    actualWorkbookPath: args.actualWorkbookPath,
    comparisonReportPath: args.comparisonReportPath,
    rowCounts: {
      "Daily Actual": sheets.dailyRows.length,
      "Priority UI Actual": sheets.priorityRows.length,
      "Income Actual": sheets.incomeRows.length,
      "Checklist Actual": sheets.checklistRows.length,
      "Transactions Actual": sheets.transactionRows.length,
      "Debt Schedule Actual": sheets.debtScheduleRows.length,
      "Debt Payments Actual": sheets.debtPaymentRows.length,
      "Debt Snapshots Actual": sheets.debtSnapshotRows.length,
      "Statements Actual": sheets.statementRows.length,
      "Card DD Actual": sheets.cardDdRows.length,
      "Manual Actions Actual": sheets.manualActionRows.length,
      "Warning Periods Actual": sheets.warningRows.length,
    },
    sheets: [
      { name: "Daily Actual", headers: dailyHeaders, rows: sheets.dailyRows },
      { name: "Priority UI Actual", headers: ["date", "day", "available_money", "total_pot_balance", "total_card_balance", "total_debt_balance", "total_debt_interest_accrued", "dashboard_warning", "card_tiles_expected", "debt_tiles_expected", "pot_tiles_expected", "events"], rows: sheets.priorityRows },
      { name: "Income Actual", headers: ["date", "income_ids", "amount"], rows: sheets.incomeRows },
      { name: "Checklist Actual", headers: ["date", "item", "amount", "pot_id", "card_id", "debt_id", "source_type", "source_id", "auto_ticked", "notes"], rows: sheets.checklistRows },
      { name: "Transactions Actual", headers: ["date", "type", "name", "amount", "pot_id", "card_id", "statement_date", "due_date", "funding_source", "note"], rows: sheets.transactionRows.sort(sortRowsByDateThenText) },
      { name: "Debt Schedule Actual", headers: ["schedule_id", "debt_id", "due_date", "planned_amount", "status"], rows: sheets.debtScheduleRows },
      { name: "Debt Payments Actual", headers: ["date", "debt_id", "requested_amount", "processed_amount", "excess_amount", "pot_id", "payment_type", "source_id", "balance_after", "note"], rows: sheets.debtPaymentRows },
      { name: "Debt Snapshots Actual", headers: ["date", "debt_id", "balance", "interest_today", "interest_total", "paid_total", "next_due", "next_amount", "status"], rows: sheets.debtSnapshotRows },
      { name: "Statements Actual", headers: ["card_id", "statement_date", "due_date", "amount", "status", "sources"], rows: sheets.statementRows },
      { name: "Card DD Actual", headers: ["date", "card_id", "statement_date", "amount", "source_breakdown", "label"], rows: sheets.cardDdRows },
      { name: "Manual Actions Actual", headers: ["date", "action_id", "action_type", "requested_amount", "processed_amount", "excess_amount", "status", "note"], rows: sheets.manualActionRows },
      { name: "Warning Periods Actual", headers: ["start_date", "end_date", "days", "warning"], rows: sheets.warningRows },
    ],
  };
}

function fundIncomeWindow({ date, window, input, billOccurrences, debtSchedules, debts, pots, availablePence, checklistRows }) {
  let amountPence = 0;
  let count = 0;
  const openingItems = input.openingBalances
    .filter((item) => !item.funded && item.dueDate >= window.date && item.dueDate <= window.endDate)
    .sort((a, b) => a.dueDate === b.dueDate ? a.order - b.order : a.dueDate.localeCompare(b.dueDate));
  const billItems = billOccurrences
    .filter((item) => !item.funded && item.dueDate >= window.date && item.dueDate <= window.endDate)
    .sort(sortBillOccurrences);
  const debtItems = debtSchedules
    .filter((item) => !item.funded && !item.paid && item.dueDate >= window.date && item.dueDate <= window.endDate)
    .sort((a, b) => a.dueDate === b.dueDate ? a.id.localeCompare(b.id) : a.dueDate.localeCompare(b.dueDate));

  for (const item of openingItems) {
    item.funded = true;
    amountPence += item.amountPence;
    count += 1;
    availablePence -= item.amountPence;
    const pot = pots.get(item.potId);
    pot.targetPence += item.amountPence;
    pot.balancePence += item.amountPence;
    checklistRows.push([date, `Fund opening balance ${item.cardId} ${item.id}`, pounds(item.amountPence), item.potId, item.cardId, null, "opening_balance", item.id, "Yes", `Due ${item.dueDate}`]);
  }

  for (const item of billItems) {
    item.funded = true;
    amountPence += item.amountPence;
    count += 1;
    availablePence -= item.amountPence;
    const pot = pots.get(item.potId);
    pot.targetPence += item.amountPence;
    pot.balancePence += item.amountPence;
    checklistRows.push([date, `Fund bill ${item.name}`, pounds(item.amountPence), item.potId, item.cardId || null, null, "scheduled_bill", item.key, "Yes", `Due ${item.dueDate}`]);
  }

  for (const item of debtItems) {
    const debt = debts.get(item.debtId);
    const fundingPence = Math.min(item.plannedAmountPence, Math.max(0, debt?.balancePence ?? item.plannedAmountPence));
    item.funded = true;
    amountPence += fundingPence;
    count += 1;
    availablePence -= fundingPence;
    const pot = pots.get("Pot6");
    pot.targetPence += fundingPence;
    pot.balancePence += fundingPence;
    checklistRows.push([date, `Fund debt payment ${item.debtName}`, pounds(fundingPence), "Pot6", null, item.debtId, "debt_schedule", item.id, "Yes", `Due ${item.dueDate}`]);
  }

  return { amountPence, count, availablePence };
}

function makeDailyRow(input) {
  const {
    date, events, incomeAddedPence, availablePence, checklistAddedPence, checklistItemsToday,
    scheduledBillsDueTodayPence, manualActionsTodayPence, debtInterestTodayPence,
    debtPaymentsTodayPence, cardDdPaidTodayPence, statementsCreatedTodayPence, pots, cards, debts,
    debtSchedules,
    cardAvailability, warning,
  } = input;
  const totalPotTargetPence = sum(potOrder.map((id) => pots.get(id)?.targetPence ?? 0));
  const totalPotBalancePence = sum(potOrder.map((id) => pots.get(id)?.balancePence ?? 0));
  const totalCardReservePence = sum(cardOrder.map((id) => cardReservePence(cards.get(id))));
  const totalCardBalancePence = sum(cardOrder.map((id) => cards.get(id)?.balancePence ?? 0));
  const totalDebtBalancePence = sum(debtOrder.map((id) => debts.get(id)?.balancePence ?? 0));
  const totalDebtInterestPence = sum(debtOrder.map((id) => debts.get(id)?.interestTotalPence ?? 0));
  const row = [
    date,
    weekday(date),
    events.length ? events.join(" | ") : null,
    pounds(incomeAddedPence),
    pounds(availablePence),
    pounds(checklistAddedPence),
    checklistItemsToday,
    pounds(scheduledBillsDueTodayPence),
    pounds(manualActionsTodayPence),
    pounds(debtInterestTodayPence),
    pounds(debtPaymentsTodayPence),
    pounds(cardDdPaidTodayPence),
    pounds(statementsCreatedTodayPence),
    pounds(totalPotTargetPence),
    pounds(totalPotBalancePence),
    pounds(totalCardReservePence),
    pounds(totalCardBalancePence),
    pounds(totalDebtBalancePence),
    pounds(totalDebtInterestPence),
    warning || null,
  ];
  for (const potId of potOrder) {
    row.push(pounds(pots.get(potId)?.targetPence ?? 0));
    row.push(pounds(pots.get(potId)?.balancePence ?? 0));
  }
  for (const cardId of cardOrder) {
    const card = cards.get(cardId);
    const availability = cardAvailability.get(cardId);
    row.push(pounds(cardReservePence(card)));
    row.push(pounds(card?.balancePence ?? 0));
    row.push(pounds(availability.forecastPence));
    row.push(pounds(availability.actualAvailablePence));
    row.push(pounds(availability.safeAvailablePence));
  }
  for (const debtId of debtOrder) {
    const debt = debts.get(debtId);
    const next = nextDebtSchedule(debtSchedules, debtId, date);
    row.push(pounds(debt?.balancePence ?? 0));
    row.push(pounds(debt?.interestTodayPence ?? 0));
    row.push(pounds(debt?.interestTotalPence ?? 0));
    row.push(pounds(debt?.paidTotalPence ?? 0));
    row.push(next?.dueDate ?? null);
    row.push(pounds(next?.plannedAmountPence ?? 0));
    row.push(debt?.status ?? null);
  }
  return row;
}

function buildCardAvailability(cards, billOccurrences, date, incomeWindows) {
  const currentWindow = [...incomeWindows].reverse().find((window) => window.date <= date) ?? incomeWindows[0];
  const result = new Map();
  for (const cardId of cardOrder) {
    const card = cards.get(cardId);
    const forecastPence = billOccurrences
      .filter((occurrence) => occurrence.cardId === cardId && occurrence.dueDate >= date && !occurrence.processed && occurrence.dueDate >= currentWindow.date && occurrence.dueDate <= currentWindow.endDate)
      .reduce((total, occurrence) => total + occurrence.amountPence, 0);
    const actualAvailablePence = (card?.limitPence ?? 0) - (card?.balancePence ?? 0);
    result.set(cardId, {
      forecastPence,
      actualAvailablePence,
      safeAvailablePence: actualAvailablePence - forecastPence,
    });
  }
  return result;
}

function buildPriorityRows(priorityDates, dailySummaries) {
  const summaryByDate = new Map(dailySummaries.map((summary) => [summary.date, summary]));
  return priorityDates.map((date) => {
    const summary = summaryByDate.get(date);
    const row = summary.dailyRow;
    const headers = dailyHeaders;
    const value = (header) => row[headers.indexOf(header)];
    return [
      date,
      weekday(date),
      value("Available Money"),
      value("Total Pot Balance"),
      value("Total Card Balance"),
      value("Total Debt Balance"),
      value("Total Debt Interest Accrued"),
      summary.warning || null,
      summary.cardTiles,
      summary.debtTiles,
      summary.potTiles,
      summary.events || null,
    ];
  });
}

function buildCardTiles(cards, cardAvailability) {
  return cardOrder.map((cardId) => {
    const availability = cardAvailability.get(cardId);
    const card = cards.get(cardId);
    return `${cardId}: bal ${formatPounds(card.balancePence)}, forecast ${formatPounds(availability.forecastPence)}, actual ${formatPounds(availability.actualAvailablePence)}, safe ${formatPounds(availability.safeAvailablePence)}`;
  }).join("; ");
}

function buildDebtTiles(debts, debtSchedules, date) {
  return debtOrder.map((debtId) => {
    const debt = debts.get(debtId);
    const next = nextDebtSchedule(debtSchedules, debtId, date);
    return `${debtId}: bal ${formatPounds(debt.balancePence)}, status ${debt.status}, next ${next?.dueDate ?? "none"} ${formatPounds(next?.plannedAmountPence ?? 0)}`;
  }).join("; ");
}

function buildPotTiles(pots) {
  return potOrder.map((potId) => {
    const pot = pots.get(potId);
    return `${potId}: target ${formatPounds(pot.targetPence)}, balance ${formatPounds(pot.balancePence)}`;
  }).join("; ");
}

function buildIncomeEvents(incomeRows) {
  const events = [];
  for (const income of incomeRows) {
    if (income.frequency === "custom") {
      for (const date of income.explicitDates) {
        if (date >= startDate && date <= endDate) events.push({ date, income });
      }
      continue;
    }
    if (income.frequency === "monthly") {
      for (let monthDate = income.startDate; monthDate <= income.endDate; monthDate = addMonthsClamped(monthDate, 1)) {
        const date = dateForDay(monthDate, income.day);
        if (date >= startDate && date <= endDate) events.push({ date, income });
      }
      continue;
    }
    const days = income.frequency === "weekly" ? 7 : 14;
    for (let date = income.startDate; date <= income.endDate; date = addDays(date, days)) {
      if (date >= startDate && date <= endDate) events.push({ date, income });
    }
  }
  const grouped = groupBy(events, (event) => event.date);
  return Array.from(grouped.entries())
    .sort(([lhs], [rhs]) => lhs.localeCompare(rhs))
    .map(([date, entries]) => ({
      date,
      incomeIds: entries.sort((a, b) => a.income.order - b.income.order).map((entry) => entry.income.id),
      amountPence: sum(entries.map((entry) => entry.income.amountPence)),
    }));
}

function buildBillOccurrences(bills) {
  const occurrences = [];
  for (const bill of bills) {
    if (bill.frequency === "monthly") {
      for (let cursor = monthStart(bill.startDate); cursor <= bill.endDate; cursor = addMonthsClamped(cursor, 1)) {
        const dueDate = dateForDay(cursor, bill.dueDay);
        if (dueDate >= bill.startDate && dueDate <= bill.endDate && dueDate >= startDate && dueDate <= endDate) {
          occurrences.push(billOccurrence(bill, dueDate));
        }
      }
    } else if (bill.frequency === "once") {
      if (bill.startDate >= startDate && bill.startDate <= endDate) occurrences.push(billOccurrence(bill, bill.startDate));
    } else {
      const step = bill.frequency === "weekly" ? 7 : bill.frequency === "biweekly" ? 14 : bill.frequency === "quarterly" ? "quarterly" : "yearly";
      for (let dueDate = bill.startDate; dueDate <= bill.endDate && dueDate <= endDate;) {
        if (dueDate >= startDate) occurrences.push(billOccurrence(bill, dueDate));
        dueDate = step === "quarterly" ? addMonthsClamped(dueDate, 3) : step === "yearly" ? addMonthsClamped(dueDate, 12) : addDays(dueDate, step);
      }
    }
  }
  return occurrences.sort(sortBillOccurrences);
}

function billOccurrence(bill, dueDate) {
  return {
    ...bill,
    dueDate,
    key: `${bill.id}@${dueDate}`,
    funded: false,
    processed: false,
  };
}

function buildDebtSchedules(debts) {
  const rows = [];
  const add = (debtId, index, dueDate, amountPence, debtName) => {
    rows.push({ id: `${debtId}-S${index}`, debtId, dueDate, plannedAmountPence: amountPence, status: "planned", funded: false, paid: false, debtName });
  };
  for (const debt of debts) {
    if (debt.id === "D1") {
      ["2028-01-01", "2028-02-01", "2028-03-01", "2028-04-01"].forEach((date, index) => add("D1", index + 1, date, 25000, debt.name));
    } else if (debt.id === "D2") {
      ["2028-01-08", "2028-01-22", "2028-02-05", "2028-02-19"].forEach((date, index) => add("D2", index + 1, date, index === 3 ? 9999 : 10000, debt.name));
    } else if (debt.id === "D3") {
      ["2028-01-15", "2028-02-15", "2028-03-15", "2028-04-15"].forEach((date, index) => add("D3", index + 1, date, 14000, debt.name));
    } else if (debt.id === "D4") {
      ["2028-01-07", "2028-01-21", "2028-02-04", "2028-02-18", "2028-03-03", "2028-03-17", "2028-03-31", "2028-04-14", "2028-04-28"].forEach((date, index) => add("D4", index + 1, date, 8000, debt.name));
    }
  }
  return rows;
}

function addStatementSource(map, cardId, statementDate, source) {
  const key = statementKey(cardId, statementDate);
  if (!map.has(key)) map.set(key, []);
  map.get(key).push(source);
}

function getStatementSources(map, cardId, statementDate) {
  return (map.get(statementKey(cardId, statementDate)) ?? []).slice().sort((a, b) => {
    if (a.date !== b.date) return a.date.localeCompare(b.date);
    return a.order - b.order;
  });
}

function cardReservePence(card) {
  return (card?.reserveEntries ?? []).reduce((total, entry) => total + Math.max(0, entry.remainingPence), 0);
}

function warningText(cards, cardAvailability, debts) {
  const warnings = [];
  for (const cardId of cardOrder) {
    const availability = cardAvailability.get(cardId);
    if (availability.actualAvailablePence < 0) warnings.push(`${cardId} over limit by ${formatPounds(Math.abs(availability.actualAvailablePence))}`);
    else if (availability.safeAvailablePence < 0) warnings.push(`${cardId} unsafe after forecast by ${formatPounds(Math.abs(availability.safeAvailablePence))}`);
  }
  for (const debtId of debtOrder) {
    const debt = debts.get(debtId);
    if (debt?.status === "atRisk") warnings.push(`${debtId} atRisk`);
  }
  return warnings.join("; ");
}

function debtStatus(debt) {
  if (!debt || debt.balancePence <= 0) return "paidOff";
  if (debt.id === "D3" || debt.id === "D5") return "atRisk";
  return "active";
}

function initialDebtStatus(debt) {
  return debt.id === "D3" || debt.id === "D5" ? "atRisk" : "active";
}

function nextDebtSchedule(schedules, debtId, date) {
  return schedules
    .filter((item) => item.debtId === debtId && !item.paid && item.dueDate > date)
    .sort((a, b) => a.dueDate.localeCompare(b.dueDate) || a.id.localeCompare(b.id))[0] ?? null;
}

function debtPaymentNote(debt) {
  if (debt.id === "D1") return "Family Loan auto-spread";
  if (debt.id === "D2") return "BNPL Laptop pay-in-4";
  if (debt.id === "D3") return "Credit Agreement minimum + extra";
  if (debt.id === "D4") return "Overdraft fixed biweekly";
  return debt.note;
}

function dailyInterestPence(balancePence, aprBasisPoints) {
  const aprDecimal = aprBasisPoints / 10000;
  const dailyRate = Math.pow(1 + aprDecimal, 1 / 365) - 1;
  return Math.max(0, Math.round(balancePence * dailyRate));
}

async function writeActualWorkbook(payload, comparison, outputPath) {
  const workbook = Workbook.create();
  for (const sheetPayload of payload.sheets) {
    const sheet = workbook.worksheets.add(sheetPayload.name);
    writeSheet(sheet, sheetPayload.headers, sheetPayload.rows);
  }
  const mismatchSheet = workbook.worksheets.add("Mismatch Report");
  writeSheet(mismatchSheet, ["sheet", "row", "column", "expected", "actual", "pence_diff"], comparison.mismatches.map((mismatch) => [
    mismatch.sheet, mismatch.row, mismatch.column, mismatch.expected, mismatch.actual, mismatch.penceDiff,
  ]));
  const errors = await workbook.inspect({
    kind: "match",
    searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
    options: { useRegex: true, maxResults: 300 },
    summary: "final formula error scan",
  });
  if (errors.ndjson.includes("#REF!") || errors.ndjson.includes("#DIV/0!") || errors.ndjson.includes("#VALUE!") || errors.ndjson.includes("#NAME") || errors.ndjson.includes("#N/A")) {
    console.warn(errors.ndjson);
  }
  const exported = await SpreadsheetFile.exportXlsx(workbook);
  await exported.save(outputPath);
  await fs.rm(`${outputPath}.inspect.ndjson`, { force: true });
}

function writeSheet(sheet, headers, rows) {
  sheet.showGridLines = false;
  const matrix = [headers, ...rows.map((row) => row.map(toWorkbookValue))];
  const range = sheet.getRangeByIndexes(0, 0, matrix.length, headers.length);
  range.values = matrix;
  sheet.getRangeByIndexes(0, 0, 1, headers.length).format = {
    fill: "#1F2937",
    font: { bold: true, color: "#FFFFFF" },
  };
  range.format.borders = { preset: "inside", style: "thin", color: "#E5E7EB" };
  sheet.freezePanes.freezeRows(1);
  for (let columnIndex = 0; columnIndex < headers.length; columnIndex += 1) {
    const header = headers[columnIndex];
    const colRange = sheet.getRangeByIndexes(1, columnIndex, Math.max(rows.length, 1), 1);
    if (isDateHeader(header)) colRange.format.numberFormat = "yyyy-mm-dd";
    else if (isMoneyHeader(header)) colRange.format.numberFormat = "#,##0.00";
    else if (integerHeaders.has(header)) colRange.format.numberFormat = "#,##0";
  }
  range.format.autofitColumns();
  range.format.autofitRows();
}

function comparePayloadToExpectedWorkbook(payload, expectedWorkbook) {
  const mismatches = [];
  const rowCounts = {};
  const actualByName = new Map(payload.sheets.map((sheet) => [sheet.name, sheet]));
  for (const [actualName, expectedName] of sheetPairs) {
    const actualSheet = actualByName.get(actualName);
    const expectedMatrix = readMatrix(expectedWorkbook, expectedName);
    const expectedHeaders = (expectedMatrix[0] ?? []).map(text).filter(Boolean);
    const expectedRows = expectedMatrix.slice(1).filter((row) => row.some((cell) => !isBlank(cell)));
    const actualHeaders = actualSheet?.headers ?? [];
    const actualRows = actualSheet?.rows ?? [];
    const sortedExpectedRows = normalizeRows(actualName, expectedHeaders, expectedRows);
    const sortedActualRows = normalizeRows(actualName, actualHeaders, actualRows);
    rowCounts[actualName] = { actual: sortedActualRows.length, expected: sortedExpectedRows.length };
    if (!actualSheet) {
      mismatches.push({ sheet: actualName, row: "sheet", column: "sheet", expected: "present", actual: "missing", penceDiff: "" });
      continue;
    }
    if (sortedActualRows.length !== sortedExpectedRows.length) {
      mismatches.push({ sheet: actualName, row: "row count", column: "rows", expected: sortedExpectedRows.length, actual: sortedActualRows.length, penceDiff: "" });
    }
    const maxRows = Math.max(sortedActualRows.length, sortedExpectedRows.length);
    for (let rowIndex = 0; rowIndex < maxRows; rowIndex += 1) {
      const expectedRow = sortedExpectedRows[rowIndex] ?? [];
      const actualRow = sortedActualRows[rowIndex] ?? [];
      const rowLabel = rowIdentifier(expectedHeaders, expectedRow, actualRow, rowIndex);
      for (const header of expectedHeaders) {
        const expectedIndex = expectedHeaders.indexOf(header);
        const actualIndex = actualHeaders.indexOf(header);
        const expectedValue = expectedRow[expectedIndex];
        const actualValue = actualIndex >= 0 ? actualRow[actualIndex] : undefined;
        const mismatch = compareCell(header, expectedValue, actualValue);
        if (mismatch) {
          mismatches.push({ sheet: actualName, row: rowLabel, column: header, ...mismatch });
        }
      }
    }
  }
  return {
    rowCounts,
    mismatches,
    totalMismatches: mismatches.length,
    firstMismatches: mismatches.slice(0, 100),
    likelyArea: likelyMismatchArea(mismatches),
  };
}

async function writeComparisonReport(payload, comparison, paths) {
  const dailySheet = payload.sheets.find((sheet) => sheet.name === "Daily Actual");
  const firstDailyDate = dailySheet?.rows?.[0]?.[0] ?? "";
  const lastDailyDate = dailySheet?.rows?.at(-1)?.[0] ?? "";
  const simulationCoveredEveryDate = dailySheet?.rows?.length === 121 && firstDailyDate === startDate && lastDailyDate === endDate;
  const status = comparison.totalMismatches === 0 ? "PASS" : "FAIL";
  const rowCountLines = Object.entries(comparison.rowCounts)
    .map(([sheet, counts]) => `| ${escapeMarkdown(sheet)} | ${counts.actual} | ${counts.expected} |`)
    .join("\n");
  const mismatchLines = comparison.firstMismatches.length === 0
    ? "| - | - | - | - | - | - |"
    : comparison.firstMismatches.map((mismatch) => (
      `| ${escapeMarkdown(mismatch.sheet)} | ${escapeMarkdown(String(mismatch.row))} | ${escapeMarkdown(String(mismatch.column))} | ${escapeMarkdown(String(mismatch.expected))} | ${escapeMarkdown(String(mismatch.actual))} | ${escapeMarkdown(String(mismatch.penceDiff))} |`
    )).join("\n");
  const report = `# Final Debt Full App Simulation Comparison - Jan Apr 2028

Fixture created successfully: ${payload.fixtureSeeded ? "Yes" : "No"}
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

## First 100 Mismatches

| Sheet | Row | Column | Expected | Actual | Pence diff |
|---|---|---|---|---|---:|
${mismatchLines}
`;
  await fs.writeFile(paths.comparisonReportPath, report);
}

function compareCell(header, expectedValue, actualValue) {
  if (isDateHeader(header)) {
    const expected = iso(expectedValue);
    const actual = iso(actualValue);
    return expected === actual ? null : { expected, actual, penceDiff: "" };
  }
  if (integerHeaders.has(header)) {
    const expected = numberValue(expectedValue);
    const actual = numberValue(actualValue);
    return expected === actual ? null : { expected: display(expectedValue), actual: display(actualValue), penceDiff: "" };
  }
  if (isMoneyHeader(header) || typeof expectedValue === "number" || typeof actualValue === "number") {
    const expected = moneyToPence(expectedValue);
    const actual = moneyToPence(actualValue);
    if (expected === actual) return null;
    return {
      expected: display(expectedValue),
      actual: display(actualValue),
      penceDiff: Number.isFinite(expected) && Number.isFinite(actual) ? actual - expected : "",
    };
  }
  const expected = normalizeTextForCompare(expectedValue, header);
  const actual = normalizeTextForCompare(actualValue, header);
  return expected === actual ? null : { expected, actual, penceDiff: "" };
}

function normalizeRows(sheetName, headers, rows) {
  return rows.slice().sort((lhs, rhs) => rowKey(sheetName, headers, lhs).localeCompare(rowKey(sheetName, headers, rhs)));
}

function rowKey(sheetName, headers, row) {
  const keys = {
    "Daily Actual": ["Date"],
    "Priority UI Actual": ["date"],
    "Income Actual": ["date", "income_ids"],
    "Checklist Actual": ["date", "source_type", "source_id", "item"],
    "Transactions Actual": ["date", "type", "name", "amount", "pot_id", "card_id"],
    "Debt Schedule Actual": ["schedule_id"],
    "Debt Payments Actual": ["date", "debt_id", "payment_type", "source_id"],
    "Debt Snapshots Actual": ["date", "debt_id"],
    "Statements Actual": ["card_id", "statement_date"],
    "Card DD Actual": ["date", "card_id", "statement_date", "amount"],
    "Manual Actions Actual": ["date", "action_id"],
    "Warning Periods Actual": ["start_date", "end_date"],
  }[sheetName] ?? headers;
  return keys.map((header) => {
    const index = headers.indexOf(header);
    if (index < 0) return "";
    const value = row[index];
    if (isDateHeader(header)) return iso(value);
    if (isMoneyHeader(header)) return String(moneyToPence(value)).padStart(14, "0");
    return normalizeTextForCompare(value, header);
  }).join("|");
}

function rowIdentifier(headers, expectedRow, actualRow, rowIndex) {
  for (const candidate of ["Date", "date", "schedule_id", "action_id", "start_date", "statement_date"]) {
    const index = headers.indexOf(candidate);
    if (index >= 0) {
      const value = isDateHeader(candidate) ? iso(expectedRow[index] ?? actualRow[index]) : text(expectedRow[index] ?? actualRow[index]);
      if (value) return value;
    }
  }
  return `row ${rowIndex + 2}`;
}

function readObjects(workbook, sheetName) {
  const matrix = readMatrix(workbook, sheetName);
  const headers = (matrix[0] ?? []).map((header) => text(header).trim());
  return matrix.slice(1)
    .filter((row) => row.some((cell) => !isBlank(cell)))
    .map((row) => Object.fromEntries(headers.map((header, index) => [header, row[index]])));
}

function readMatrix(workbook, sheetName) {
  const sheet = workbook.worksheets.getItem(sheetName);
  return sheet.getUsedRange(true).values ?? [];
}

function toWorkbookValue(value) {
  if (isBlank(value)) return null;
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) return new Date(`${value}T00:00:00.000Z`);
  return value;
}

function statementDateForCharge(card, chargeDate) {
  const day = Number(chargeDate.slice(8, 10));
  const monthBase = day <= card.statementDay ? chargeDate : addMonthsClamped(chargeDate, 1);
  return dateForDay(monthBase, card.statementDay);
}

function dueDateForStatement(card, statementDate) {
  const dueBase = card.dueDay <= card.statementDay ? addMonthsClamped(statementDate, 1) : statementDate;
  return dateForDay(dueBase, card.dueDay);
}

function statementStatus(statementDate) {
  if (statementDate < startDate) return "created_before_run";
  if (statementDate > endDate) return "expected_after_run";
  return "created_inside_run";
}

function statementKey(cardId, statementDate) {
  return `${cardId}|${statementDate}`;
}

function sortBillOccurrences(lhs, rhs) {
  return lhs.dueDate.localeCompare(rhs.dueDate) || lhs.order - rhs.order || lhs.id.localeCompare(rhs.id);
}

function sortStatements(lhs, rhs) {
  return lhs.statementDate.localeCompare(rhs.statementDate) || lhs.cardId.localeCompare(rhs.cardId);
}

function sortRowsByDateThenText(lhs, rhs) {
  return String(lhs[0]).localeCompare(String(rhs[0])) || lhs.map(String).join("|").localeCompare(rhs.map(String).join("|"));
}

function groupBy(items, keyFn) {
  const map = new Map();
  for (const item of items) {
    const key = keyFn(item);
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(item);
  }
  return map;
}

function sum(values) {
  return values.reduce((total, value) => total + (value ?? 0), 0);
}

function moneyToPence(value) {
  if (isBlank(value)) return 0;
  if (value instanceof Date) return Number.NaN;
  if (typeof value === "number") return Math.round(value * 100);
  const parsed = Number(String(value).replace(/[^0-9.-]/g, ""));
  return Number.isFinite(parsed) ? Math.round(parsed * 100) : Number.NaN;
}

function numberValue(value) {
  if (isBlank(value)) return 0;
  if (typeof value === "number") return value;
  const parsed = Number(String(value).replace(/,/g, ""));
  return Number.isFinite(parsed) ? parsed : Number.NaN;
}

function pounds(pence) {
  return Math.round((pence / 100) * 100) / 100;
}

function formatPounds(pence) {
  const absolute = Math.abs(pence);
  const formatted = (absolute / 100).toLocaleString("en-GB", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  return pence < 0 ? `£-${formatted}` : `£${formatted}`;
}

function iso(value) {
  if (isBlank(value)) return "";
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  if (typeof value === "number") return new Date(Date.UTC(1899, 11, 30) + Math.round(value * 86400000)).toISOString().slice(0, 10);
  const trimmed = String(value).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return trimmed;
  const parsed = new Date(trimmed);
  return Number.isNaN(parsed.getTime()) ? trimmed : parsed.toISOString().slice(0, 10);
}

function text(value) {
  if (isBlank(value)) return "";
  if (value instanceof Date) return iso(value);
  return String(value).trim();
}

function splitList(value) {
  return text(value).split(/\s*,\s*/).map((part) => part.trim()).filter(Boolean);
}

function isBlank(value) {
  return value === null || value === undefined || value === "";
}

function display(value) {
  if (isBlank(value)) return "";
  if (value instanceof Date) return iso(value);
  return String(value);
}

function normalizeTextForCompare(value, header = "") {
  const normalized = text(value).replace(/\s+/g, " ");
  return /^events$/i.test(header) ? normalizeEventList(normalized) : normalized;
}

function normalizeEventList(value) {
  const parts = value.split(/\s*\|\s*/).map((part) => part.trim()).filter(Boolean);
  return parts.length <= 1 ? value : parts.sort((lhs, rhs) => lhs.localeCompare(rhs)).join(" | ");
}

function isMoneyHeader(header) {
  if (isDateHeader(header) || integerHeaders.has(header)) return false;
  return moneyHeaderPatterns.some((pattern) => pattern.test(header));
}

function isDateHeader(header) {
  return dateHeaders.has(header) || /Next Due$/i.test(header);
}

function addDays(isoDate, days) {
  const date = new Date(`${isoDate}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function addMonthsClamped(isoDate, months) {
  const year = Number(isoDate.slice(0, 4));
  const month = Number(isoDate.slice(5, 7));
  const day = Number(isoDate.slice(8, 10));
  const targetMonthIndex = year * 12 + (month - 1) + months;
  const targetYear = Math.floor(targetMonthIndex / 12);
  const targetMonth = (targetMonthIndex % 12) + 1;
  const targetDay = Math.min(day, daysInMonth(targetYear, targetMonth));
  return `${targetYear}-${String(targetMonth).padStart(2, "0")}-${String(targetDay).padStart(2, "0")}`;
}

function dateForDay(baseIsoDate, day) {
  const year = Number(baseIsoDate.slice(0, 4));
  const month = Number(baseIsoDate.slice(5, 7));
  const targetDay = Math.min(day, daysInMonth(year, month));
  return `${year}-${String(month).padStart(2, "0")}-${String(targetDay).padStart(2, "0")}`;
}

function monthStart(isoDate) {
  return `${isoDate.slice(0, 7)}-01`;
}

function daysInMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function daysInclusive(start, end) {
  return Math.round((new Date(`${end}T00:00:00.000Z`) - new Date(`${start}T00:00:00.000Z`)) / 86400000) + 1;
}

function weekday(isoDate) {
  return new Intl.DateTimeFormat("en-GB", { weekday: "short", timeZone: "UTC" }).format(new Date(`${isoDate}T00:00:00.000Z`));
}

function escapeMarkdown(value) {
  return value.replaceAll("|", "\\|").replaceAll("\n", " ");
}

function likelyMismatchArea(mismatches) {
  if (mismatches.length === 0) return "none";
  const haystack = mismatches.map((mismatch) => `${mismatch.sheet} ${mismatch.column}`).join(" ");
  if (/Debt/.test(haystack)) return "debt interest, debt payments, or debt status";
  if (/Card|Statement|DD|Reserve|Forecast|Safe/.test(haystack)) return "credit cards, statements, direct debits, or forecasts";
  if (/Checklist|Income|Available/.test(haystack)) return "income window or checklist funding";
  if (/Transactions/.test(haystack)) return "bill recurrence or transaction posting";
  return "daily app state";
}
