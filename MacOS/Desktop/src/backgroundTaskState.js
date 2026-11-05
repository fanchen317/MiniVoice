export function backgroundTaskState(state,hideScan=false){
  const tasks=state.tasks||{},jobs=state.jobs||[];
  const active=jobs.filter(job=>!job.finished).length+Number(Boolean(state.importing))+Number(Boolean(tasks.downloadingModel))+Number(tasks.wordTiming?.phase==='analyzing');
  const hasScan=Boolean(state.importing||(!hideScan&&state.scanSummary&&state.scanSummary!=='尚未扫描'));
  const hasRecords=hasScan||jobs.length>0||Boolean(tasks.modelStatus||tasks.notice||tasks.wordTiming&&tasks.wordTiming.phase!=='idle');
  const failed=Boolean((hasScan&&state.issues?.length)||jobs.some(job=>job.failed)||tasks.modelFailed||tasks.notice?.kind==='failure');
  return {active,hasScan,hasRecords,failed};
}
