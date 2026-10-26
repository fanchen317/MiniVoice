export function sheetDragDismiss(distance,velocity,height){
 const threshold=Math.min(120,Math.max(64,height*.22));
 return distance>=threshold||(distance>=24&&velocity>.65);
}
