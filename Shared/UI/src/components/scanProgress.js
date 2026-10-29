export function scanProgress(snapshot={}){
 const completed=Math.max(0,Math.floor(Number(snapshot.scanCompleted)||0));
 const total=Math.max(0,Math.floor(Number(snapshot.scanTotal)||0));
 const running=Boolean(snapshot.scanning),paused=Boolean(snapshot.scanPaused)&&!running;
 return {visible:running||paused,running,paused,completed,total,
  percent:total>0?Math.min(100,Math.floor(completed/total*100)):null,
  title:paused?'扫描已暂停':total>0?`正在扫描 · ${Math.min(completed,total)} / ${total} 首`:`正在查找 · 已发现 ${completed} 首`,
  detail:snapshot.scanDetail||(paused?'返回设置继续扫描':'正在查找音乐文件…')};
}
