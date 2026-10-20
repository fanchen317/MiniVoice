export const defaultOrdering={tracks:{field:'added',ascending:false},artists:{field:'name',ascending:true},albums:{field:'name',ascending:true}};
export function groupName(value,artist){return value?.trim()||(artist?'未知歌手':'未知专辑');}
export function sortCategory(destination,group){return !group&&['artists','albums'].includes(destination)?destination:'tracks';}
export function normalizeOrdering(value){
  return Object.fromEntries(Object.entries(defaultOrdering).map(([category,fallback])=>{
    const input=value?.[category],allowed=category==='tracks'?['title','artist','album','sourceAdded','added']:['name','count'];
    return [category,{field:allowed.includes(input?.field)?input.field:fallback.field,ascending:typeof input?.ascending==='boolean'?input.ascending:fallback.ascending}];
  }));
}
export function emptyListMessage({destination,query,hasFolders}){
  if(query.trim())return destination==='favorites'?'没有找到匹配的收藏音乐':'没有找到匹配的歌曲';
  if(destination==='favorites')return '暂无收藏音乐';
  if(!hasFolders)return '在设置中添加你的音乐文件夹';
  if(destination==='recent')return '播放歌曲后，记录会保存在这里';
  if(!['all','artists','albums'].includes(destination))return '右键点击歌曲，选择“加入歌单”';
  return '没有找到歌曲';
}
