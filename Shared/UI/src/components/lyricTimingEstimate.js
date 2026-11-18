// Display-only timing. These are linguistic priors, not measured vocal alignment.
const punctuation=/^[\p{P}\p{Z}\s]+$/u;
const latin=/^[a-zà-ž]+$/iu;
const joiner=/^['’]$/u;
// These small kana join the previous sound (unlike the moraic っ/ッ).
const joinedKana=/^[ゃゅょゎャュョヮ]$/u;
export function estimateLyricTiming(text,start,limit){
 const glyphs=typeof Intl.Segmenter==='function'?[...new Intl.Segmenter('zh',{granularity:'grapheme'}).segment(text)].map(x=>x.segment):Array.from(text);
 if(!glyphs.length||!Number.isFinite(start)||!Number.isFinite(limit)||limit<=start)return [];
 const weights=glyphs.map(g=>punctuation.test(g)?0:1);
 // Latin vowel nuclei approximate syllables; distribute within each written word
 // so long spellings do not consume the same time as many Chinese syllables.
 for(let i=0;i<glyphs.length;){
  if(!latin.test(glyphs[i])){i++;continue;}
  let j=i+1;while(j<glyphs.length&&(latin.test(glyphs[j])||(joiner.test(glyphs[j])&&latin.test(glyphs[j+1]||''))))j++;
  const letters=glyphs.slice(i,j).filter(g=>latin.test(g));
  const token=letters.join('').toLowerCase();
  const nuclei=(token.replace(/e$/,'').match(/[aeiouyà-öø-ÿ]+/g)||[]).length;
  const syllables=Math.max(1,nuclei),weight=syllables/letters.length;
  for(let k=i;k<j;k++)if(latin.test(glyphs[k]))weights[k]=weight;
  i=j;
 }
 // A combined Japanese syllable should not be stretched into two full beats.
 for(let i=1;i<glyphs.length;i++)if(joinedKana.test(glyphs[i])&&/[ぁ-ゖァ-ヺ]/u.test(glyphs[i-1])){weights[i-1]-=.2;weights[i]=.2;}
 const voiced=weights.map((w,i)=>w>0?i:-1).filter(i=>i>=0);
 if(!voiced.length)return glyphs.map(text=>({text,start,end:start}));
 const pauses=new Map();
 for(let n=0;n<voiced.length;n++){
  const i=voiced[n],next=voiced[n+1]??glyphs.length;
  const boundary=glyphs.slice(i+1,next).join('');
  if(n<voiced.length-1&&/[，,、；;：:。.!！?？…]/u.test(boundary)){
   pauses.set(i,/[。.!！?？…]/u.test(boundary)?.65:.32);
   weights[i]*=1.12;
  }
 }
 weights[voiced.at(-1)]*=1.55;
 const units=weights.reduce((a,b)=>a+b,0),available=limit-start;
 // Long inter-line gaps must not turn a short phrase into a ten-second vowel.
 const span=Math.min(available,Math.max(1.2,units*.48));
 const tail=Math.min(.24,span*.06),budget=span-tail;
 const requested=[...pauses.values()].reduce((a,b)=>a+b,0);
 const pauseScale=requested?Math.min(1,budget*.18/requested):0;
 const singing=budget-requested*pauseScale;
 let cursor=start;
 return glyphs.map((text,i)=>{
  const begin=cursor;
  if(weights[i]>0)cursor+=singing*weights[i]/units;
  const end=cursor;
  cursor+=(pauses.get(i)||0)*pauseScale;
  return {text,start:begin,end};
 });
}
