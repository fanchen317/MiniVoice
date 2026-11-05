/** Evaluation needs externally annotated timing, not model probabilities or
 * interpolation coverage. Units must share exact text boundaries. */
function evaluateWordTiming(reference,predicted,{toleranceMs=150}={}){
 if(!Number.isFinite(toleranceMs)||toleranceMs<0)throw Error('无效评测容差');
 if(!Array.isArray(reference)||!Array.isArray(predicted)||!reference.length)throw Error('需要人工标注和待评测时间轴');
 const index=rows=>{let offset=0;return rows.map(row=>{if(typeof row.text!=='string'||!row.text.length||!Number.isFinite(row.start)||!Number.isFinite(row.end)||row.start<0||row.end<=row.start)throw Error('无效评测时间点');const unit={...row,from:offset,to:offset+row.text.length};offset=unit.to;return unit;});};
 const truth=index(reference),actual=index(predicted);if(truth.map(row=>row.text).join('')!==actual.map(row=>row.text).join(''))throw Error('评测原文必须完全相同');
 const byBoundary=new Map(actual.map(row=>[`${row.from}:${row.to}`,row]));let matched=0,aligned=0,total=0;const errors=[];
 for(const row of truth){const weight=[...row.text].filter(char=>!/[\p{P}\p{Z}\s]/u.test(char)).length;if(!weight)continue;total+=weight;const found=byBoundary.get(`${row.from}:${row.to}`);if(!found||found.timingSource==='estimated')continue;aligned+=weight;const start=Math.abs(row.start-found.start)*1000,end=Math.abs(row.end-found.end)*1000;errors.push({text:row.text,startErrorMs:start,endErrorMs:end});if(start<=toleranceMs&&end<=toleranceMs)matched+=weight;}
 return {toleranceMs,matchedCharacters:matched,totalCharacters:total,matchRate:total?matched/total:0,comparableRate:total?aligned/total:0,errors};
}
module.exports={evaluateWordTiming};
