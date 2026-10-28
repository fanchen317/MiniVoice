/** Local developer preview. Demo playback only; production hosts use real system audio. */
import http from 'node:http';
import {spawn} from 'node:child_process';
import {createInterface} from 'node:readline';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const child=spawn(path.join(root,'.build/work/shared-core/minivoice-core'),[],{stdio:['pipe','pipe','inherit']});
const pending=[];createInterface({input:child.stdout}).on('line',line=>{const entry=pending.shift();if(!entry)return;try{const result=JSON.parse(line);result.ok?entry.resolve(result.value):entry.reject(new Error(result.error));}catch(error){entry.reject(error);}});
child.on('exit',()=>{for(const entry of pending.splice(0))entry.reject(new Error('Core stopped'));});
const core=request=>new Promise((resolve,reject)=>{pending.push({resolve,reject});child.stdin.write(JSON.stringify(request)+'\n');});
const songs=Array.from({length:180},(_,i)=>({id:String(i),title:['七里香','晴天','夜曲','稻香'][i%4]+' '+(i+1),artist:['周杰伦','林俊杰','陈奕迅'][i%3],album:'演示专辑 '+(Math.floor(i/6)+1),duration:240000}));
let current=null,position=0,playing=false,at=Date.now(),favorites=[],recent=[],playlists=[],mode=1;
function tick(){const now=Date.now();if(playing)position=Math.min(240000,position+now-at);at=now;}
const rawLyrics='[00:00.000]这是跨平台界面预览\n[00:00.000]Shared player preview\n[00:04.000]页面和歌词使用同一份代码\n[00:04.000]The same interface on each platform\n[00:08.000]真实播放由系统适配层提供';
async function request(value){if(value.version!==1)throw new Error('Unsupported version');tick();switch(value.kind){
 case 'core':return core(value.request);
 case 'snapshot':return {songs,current,position,playing,favorites,recent,playlists,mode,queue:songs.map(song=>song.id),rawLyrics:current===null?'':rawLyrics};
 case 'action':{const p=value.payload||{},ids=p.ids||[];switch(value.name){
  case 'getSettings':return {folders:[],recursive:false,crashCount:0,actions:['clearRecent']};
  case 'readLyrics':return {title:songs.find(song=>song.id===p.id)?.title||'',raw:rawLyrics};
  case 'favorite':favorites=favorites.includes(p.id)?favorites.filter(id=>id!==p.id):[...favorites,p.id];break;
  case 'favoriteMany':favorites=p.value?[...new Set([...favorites,...ids])]:favorites.filter(id=>!ids.includes(id));break;
  case 'mode':mode=p.value;break;
  case 'queueSelect':current=p.id;position=0;playing=true;break;
  case 'createPlaylist':if(!p.name.trim()||playlists.some(list=>list.name===p.name.trim()))throw new Error('歌单名称为空或重复');playlists.push({id:p.name.trim(),name:p.name.trim(),ids:[...new Set(ids)]});return {id:p.name.trim()};
  case 'renamePlaylist':{const list=playlists.find(list=>list.id===p.playlist);if(!list)throw new Error('歌单不存在');if(!p.name.trim()||playlists.some(item=>item!==list&&item.name===p.name.trim()))throw new Error('歌单名称为空或重复');list.name=p.name.trim();list.id=list.name;return {id:list.id};}
  case 'deletePlaylist':playlists=playlists.filter(list=>list.id!==p.playlist);break;
  case 'addManyToPlaylist':case 'removeManyFromPlaylist':{const list=playlists.find(list=>list.id===p.playlist);if(!list)throw new Error('歌单不存在');list.ids=value.name==='addManyToPlaylist'?[...new Set([...list.ids,...ids])]:list.ids.filter(id=>!ids.includes(id));break;}
  case 'clearRecent':recent=[];break;
  case 'settings':throw new Error('浏览器演示不访问系统设置');
  default:throw new Error('Unsupported operation');}return true;}

 case 'play':if(!songs.some(song=>song.id===value.id))throw new Error('Unknown song');current=value.id;position=0;playing=true;recent=[value.id,...recent.filter(id=>id!==value.id)];return true;
 case 'toggle':if(current!==null)playing=!playing;return true;
 case 'seek':position=Math.max(0,Math.min(240000,Number(value.position)||0));return true;
 case 'skip':current=String((Number(current||0)+(value.delta<0?-1:1)+songs.length)%songs.length);position=0;return true;
 default:throw new Error('Unsupported operation');}}
const server=http.createServer(async(req,res)=>{try{
 if(req.method==='POST'&&req.url==='/api/request'){if(req.headers.origin&&req.headers.origin!==`http://127.0.0.1:${server.address().port}`){res.writeHead(403).end();return;}let body='';for await(const chunk of req){body+=chunk;if(body.length>4*1024*1024)throw new Error('Request too large');}const value=await request(JSON.parse(body));res.writeHead(200,{'Content-Type':'application/json'}).end(JSON.stringify({ok:true,value}));return;}
 if(req.method!=='GET')throw new Error('Method not supported');
 const url=new URL(req.url,'http://localhost'),name=url.pathname==='/'?'index.html':decodeURIComponent(url.pathname.slice(1));if(name.includes('..')||name.includes('\\')||!(name==='index.html'||name.startsWith('assets/')))throw new Error('Invalid path');
 const data=await readFile(path.join(root,'.build/work/shared-ui',name));res.writeHead(200,{'Content-Type':name.endsWith('.js')?'application/javascript':name.endsWith('.css')?'text/css':name.endsWith('.png')?'image/png':'text/html','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none'; frame-src 'none'"}).end(data);
 }catch(error){res.writeHead(400,{'Content-Type':'application/json'}).end(JSON.stringify({ok:false,error:error.message}));}});
server.listen(Number(process.env.MINIVOICE_PREVIEW_PORT||4178),'127.0.0.1',()=>console.log(`Preview: http://127.0.0.1:${server.address().port} (demo library)`));
for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>{child.kill();server.close(()=>process.exit());});
