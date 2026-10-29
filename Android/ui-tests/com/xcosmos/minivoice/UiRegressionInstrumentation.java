package com.xcosmos.minivoice;

import android.app.*;
import android.content.*;
import android.graphics.RectF;
import android.net.Uri;
import android.os.*;
import android.view.*;
import android.widget.*;
import java.lang.reflect.*;
import java.io.*;
import java.util.*;

/** Runs real Android layouts and input on a dedicated emulator, without a third-party runner. */
public final class UiRegressionInstrumentation extends Instrumentation {
    private MainActivity activity;
    private Bundle arguments;
    private final StringBuilder report=new StringBuilder();
    @Override public void onCreate(Bundle args){super.onCreate(args);arguments=args;start();}
    @Override public void onStart(){Bundle result=new Bundle();try{
        if("chrome".equals(arguments.getString("mode"))){chromeContracts();result.putString("stream",report+"UI_CHROME_PASS\n");finish(Activity.RESULT_OK,result);return;}
        if("scanProgress".equals(arguments.getString("mode"))){scanProgressUi();result.putString("stream",report+"UI_SCAN_PROGRESS_PASS\n");finish(Activity.RESULT_OK,result);return;}
        if("keyboard".equals(arguments.getString("mode"))){portableKeyboard();result.putString("stream",report+"UI_KEYBOARD_PASS\n");finish(Activity.RESULT_OK,result);return;}
        if("crash".equals(arguments.getString("mode"))){new Thread(()->{throw new IllegalStateException("UI_CRASH_PROBE");},"diagnostic-crash-probe").start();SystemClock.sleep(10000);throw new AssertionError("Crash handler did not terminate process");}
        if("tags".equals(arguments.getString("mode"))){tagEditing();result.putString("stream",report+"UI_TAG_EDIT_PASS\n");finish(Activity.RESULT_OK,result);return;}
        if("playerFlow".equals(arguments.getString("mode"))){portablePlayer();result.putString("stream",report+"UI_PLAYER_FLOW_PASS\n");finish(Activity.RESULT_OK,result);return;}
        if("surfaces".equals(arguments.getString("mode"))){portablePlayer();result.putString("stream",report+"UI_SURFACES_PASS\n");finish(Activity.RESULT_OK,result);return;}
        if("wall".equals(arguments.getString("mode"))){portablePlayer();result.putString("stream",report+"UI_WALL_PASS\n");finish(Activity.RESULT_OK,result);return;}
        if("portable".equals(arguments.getString("mode"))){portablePlayer();result.putString("stream",report+"UI_PORTABLE_PASS\n");finish(Activity.RESULT_OK,result);return;}
        if("modals".equals(arguments.getString("mode"))){launch();modalPresentation();result.putString("stream",report+"UI_MODALS_PASS\n");finish(Activity.RESULT_OK,result);return;}
        launch();
        if("prepare".equals(arguments.getString("mode"))){prepareProcessRestart();result.putString("stream",report+"UI_PREPARE_PASS\n");finish(Activity.RESULT_OK,result);return;}
        if("provider".equals(arguments.getString("mode"))){incrementalProvider();result.putString("stream",report+"UI_PROVIDER_PASS\n");finish(Activity.RESULT_OK,result);return;}
        if("restart".equals(arguments.getString("mode"))){verifyProcessRestart();result.putString("stream",report+"UI_PROCESS_RESTART_PASS\n");finish(Activity.RESULT_OK,result);return;}
        for(String style:new String[]{"library","simple","wall"})for(String theme:new String[]{"light","dark"}){
            main(()->{activity.getSharedPreferences("library",0).edit().putString("player_style",style).putString("appearance",theme).commit();home().applyAppearance();home().showDrawer(false);});settle();
            for(String section:new String[]{"歌手","专辑"})navigation(style,section);
            drawerCycle(style,theme);
            report.append("PASS ").append(style).append('/').append(theme).append(" navigation, anchors, drawer reopen\n");
            Bundle progress=new Bundle();progress.putString("stream","PASS "+style+"/"+theme+" navigation, anchors, drawer reopen\n");sendStatus(0,progress);
        }
        persistentRestart();
        expansionAndLyrics();
        diagnosticsExport();
        incrementalProvider();
        prepareProcessRestart();
        result.putString("stream",report+"UI_REGRESSION_PASS\n");finish(Activity.RESULT_OK,result);
    }catch(Throwable failure){result.putString("stream",report+android.util.Log.getStackTraceString(failure)+"\nUI_REGRESSION_FAIL\n");finish(Activity.RESULT_CANCELED,result);}}
    private void main(Runnable action){runOnMainSync(action);}
    private static Object field(Object owner,String name){try{Field f=owner.getClass().getDeclaredField(name);f.setAccessible(true);return f.get(owner);}catch(Exception e){throw new RuntimeException(e);}}
    private static Object call(Object owner,String name,Class<?>[] types,Object... args){try{Method m=owner.getClass().getDeclaredMethod(name,types);m.setAccessible(true);return m.invoke(owner,args);}catch(Exception e){throw new RuntimeException(e);}}
    private HomeScreen home(){return (HomeScreen)field(activity,"home");}
    private PlayerStylePage page(){return (PlayerStylePage)field(home(),"stylePage");}
    private AbsListView list(){return (AbsListView)field(page(),"list");}
    private WallView wall(){return (WallView)field(home(),"wall");}
    private void settle(){waitForIdleSync();SystemClock.sleep(650);waitForIdleSync();}
    @SuppressWarnings("unchecked") private void launch(){
        activity=(MainActivity)startActivitySync(new Intent(getTargetContext(),MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK));settle();
        // Wait for startup cache restoration before installing a deterministic 160-artist fixture.
        for(int i=0;i<100&&(boolean)field(activity,"scanning");i++)SystemClock.sleep(100);
        main(()->{List<Song> library=(List<Song>)field(activity,"library");library.clear();for(int i=0;i<320;i++){String group=String.format(Locale.ROOT,"Artist %03d",i/2);Song song=new Song(-10000-i,180000,0,"Song "+i,group,"Album "+String.format(Locale.ROOT,"%03d",i/2),"song-"+i+".mp3",Uri.parse("content://test-fixture/audio/"+i));song.artworkPrepared=true;song.lyricsPrepared=true;library.add(song);}call(activity,"refreshWall",new Class<?>[0]);home().showDrawer(false);});settle();
    }
    private void select(String section){main(()->call(activity,"selectSection",new Class<?>[]{String.class},section));settle();}
    private int[] anchor(){int[] value=new int[2];main(()->{value[0]=list().getFirstVisiblePosition();value[1]=list().getChildAt(0).getTop()-list().getPaddingTop();});return value;}
    private void navigation(String style,String section){
        select(section);
        String filter=section.equals("歌手")?"Artist 0":"Album 0";
        main(()->((EditText)field(home(),"searchInput")).setText(filter));settle();
        if(style.equals("wall")){
            swipe(wall(),.72f,.65f,.28f,.36f);settle();WallView.CameraState[] before={null};main(()->before[0]=wall().cameraState());
            main(()->home().saveBrowseState());tapWallCard();settle();check(field(activity,"groupName")!=null,"Wall card did not open");
            main(()->activity.onBackPressed());settle();check(field(activity,"groupName")==null,"Wall group did not close");check(((String)field(activity,"query")).equals(filter.toLowerCase(Locale.ROOT)),"Wall parent query lost");
            main(()->{WallView.CameraState after=wall().cameraState();check(Math.abs(after.x-before[0].x)<2&&Math.abs(after.y-before[0].y)<2,"Wall return lost camera");});return;
        }
        swipe(list(),.5f,.85f,.5f,.2f);settle();int[] before=anchor();check(before[0]>0,"Fixture grid did not scroll");
        for(int cycle=0;cycle<4;cycle++){
            if(cycle==3){main(()->{for(int i=0;i<24;i++)list().scrollListBy(-list().getHeight());list().scrollListBy(25);});settle();before=anchor();check(before[0]==0&&before[1]<0,"First-row offset fixture failed");}
            final View[] row={null};main(()->{for(int i=0;i<list().getChildCount();i++){View candidate=list().getChildAt(i);float center=(candidate.getTop()+candidate.getBottom())/2f;if(center>list().getPaddingTop()&&center<list().getHeight()-list().getPaddingBottom()){row[0]=candidate;break;}}});check(row[0]!=null,"No tappable grid card");tap(row[0]);settle();check(field(activity,"groupName")!=null,"Grid card did not open");
            main(()->activity.onBackPressed());settle();check(field(activity,"groupName")==null,"Grid group did not close");check(((String)field(activity,"query")).equals(filter.toLowerCase(Locale.ROOT)),"Grid parent query lost");int[] after=anchor();
            check(before[0]==after[0]&&Math.abs(before[1]-after[1])<3,"Grid return lost position: "+Arrays.toString(before)+" -> "+Arrays.toString(after));
        }
    }
    @SuppressWarnings("unchecked") private void tapWallCard(){
        float[] point={-1,-1};main(()->{List<Object> hits=(List<Object>)field(wall(),"hits");for(Object hit:hits){RectF bounds=(RectF)field(hit,"bounds");if(bounds.centerX()>50&&bounds.centerX()<wall().getWidth()-50&&bounds.centerY()>180&&bounds.centerY()<wall().getHeight()-250){point[0]=bounds.centerX();point[1]=bounds.centerY();break;}}});check(point[0]>=0,"No visible wall card");tap(wall(),point[0],point[1]);
    }
    private void drawerCycle(String style,String theme){for(int i=0;i<2;i++){main(()->home().showDrawer(true));settle();check(home().isDrawerOpen(),"Drawer failed to reopen");
            if(i==0){main(()->{activity.getSharedPreferences("library",0).edit().putString("player_style",style.equals("wall")?"simple":"wall").commit();home().applyAppearance();});settle();check(home().isDrawerOpen(),"Style switch closed the drawer");main(()->{activity.getSharedPreferences("library",0).edit().putString("player_style",style).commit();home().applyAppearance();});settle();}
            screenshot("drawer-"+style+"-"+theme+"-"+i);main(()->home().showDrawer(false));settle();check(!home().isDrawerOpen(),"Drawer failed to close");}}
    private void persistentRestart(){
        main(()->{activity.getSharedPreferences("library",0).edit().putString("player_style","library").putString("appearance","light").commit();home().applyAppearance();});select("歌手");swipe(list(),.5f,.85f,.5f,.2f);settle();int[] before=anchor();
        main(()->{BrowseStateStore store=new BrowseStateStore(activity);store.sorting("artists","title",true);store.query("专辑\n","Album");home().saveBrowseState();call(activity,"saveNavigation",new Class<?>[0]);activity.finish();});settle();launch();
        int[] after=anchor();check(before[0]==after[0]&&Math.abs(before[1]-after[1])<3,"Activity restart lost grid anchor");
        main(()->{BrowseStateStore store=new BrowseStateStore(activity);check(store.query("专辑\n").equals("Album"),"Query not durable");check(store.ascending("artists"),"Sort not durable");});report.append("PASS persistent restart, queries and sorting\n");
    }
    private void expansionAndLyrics(){
        main(()->{activity.getSharedPreferences("library",0).edit().putString("player_style","library").commit();home().applyAppearance();});select("歌曲");
        main(()->{Song song=new Song(-10000,180000,0,"Test","Artist","Album","fixture",Uri.parse("content://test-fixture/audio/0"));page().setSong(song);page().setLyrics(Lyrics.parse("[00:01]Hello\n[00:01]你好\n[00:02]World\n[00:02]世界"));page().toggleExpanded();});settle();
        main(()->{call(page(),"toggleLyricsExpanded",new Class<?>[0]);home().saveBrowseState();});settle();
        main(()->{activity.getSharedPreferences("library",0).edit().putString("appearance","dark").commit();home().applyAppearance();check((boolean)field(page(),"expanded"),"Player expansion lost on theme switch");check((boolean)field(page(),"lyricsExpanded"),"Lyrics expansion lost on theme switch");});settle();screenshot("bilingual-expanded");
        NativeLyricsView lyrics=(NativeLyricsView)field(page(),"lyricView");ListView rows=(ListView)field(lyrics,"list");main(()->{check(rows.getAdapter().getCount()==2,"Bilingual lines were not merged in actual view");TextView row=(TextView)rows.getAdapter().getView(0,null,rows);check(row.getText().toString().equals("Hello\n你好"),"Actual lyric row lost translation");});
        main(()->{call(page(),"toggleLyricsExpanded",new Class<?>[0]);page().toggleExpanded();});settle();report.append("PASS player/lyric expansion across rebuild and bilingual row rendering\n");
    }
    private void diagnosticsExport()throws Exception{
        java.io.ByteArrayOutputStream output=new java.io.ByteArrayOutputStream();Diagnostics.event("UI regression export check");Diagnostics.export(activity,output);java.util.zip.ZipInputStream zip=new java.util.zip.ZipInputStream(new java.io.ByteArrayInputStream(output.toByteArray()));boolean environment=false,events=false;java.util.zip.ZipEntry entry;while((entry=zip.getNextEntry())!=null){environment|=entry.getName().equals("environment.txt");events|=entry.getName().equals("events.txt");check(!entry.getName().contains("index"),"Export leaked music index");}check(environment&&events,"Incomplete diagnostic zip");report.append("PASS diagnostic ZIP contents\n");
    }
    private void prepareProcessRestart(){
        main(()->{activity.getSharedPreferences("library",0).edit().putString("player_style","library").putString("appearance","light").commit();home().applyAppearance();});select("歌手");swipe(list(),.5f,.85f,.5f,.2f);settle();int[] expected=anchor();check(expected[0]>0,"Restart fixture not scrolled");
        main(()->{call(activity,"saveNavigation",new Class<?>[0]);activity.getSharedPreferences("library",0).edit().putInt("ui_expected_index",expected[0]).putInt("ui_expected_offset",expected[1]).commit();});
    }
    private void verifyProcessRestart()throws Exception{
        int[] actual=anchor();android.content.SharedPreferences prefs=activity.getSharedPreferences("library",0);int first=prefs.getInt("ui_expected_index",-1),offset=prefs.getInt("ui_expected_offset",0);
        check(first==actual[0]&&Math.abs(offset-actual[1])<3,"Force-stop restart lost grid position: "+first+","+offset+" -> "+Arrays.toString(actual));
        check(Diagnostics.crashCount()>0,"Uncaught crash did not produce a local log");
        java.io.ByteArrayOutputStream output=new java.io.ByteArrayOutputStream();Diagnostics.export(activity,output);java.util.zip.ZipInputStream zip=new java.util.zip.ZipInputStream(new java.io.ByteArrayInputStream(output.toByteArray()));boolean found=false;java.util.zip.ZipEntry entry;
        while((entry=zip.getNextEntry())!=null){java.io.ByteArrayOutputStream contents=new java.io.ByteArrayOutputStream();byte[] buffer=new byte[4096];int count;while((count=zip.read(buffer))>0)contents.write(buffer,0,count);if(entry.getName().startsWith("crash-")&&contents.toString("UTF-8").contains("UI_CRASH_PROBE"))found=true;}
        check(found,"Diagnostic ZIP omitted crash stack");report.append("PASS force-stop/process restart and actual uncaught-crash ZIP\n");
    }
    private void screenshot(String name){android.graphics.Bitmap image=getUiAutomation().takeScreenshot();if(image==null)return;try{java.io.File folder=new java.io.File(getTargetContext().getExternalFilesDir(null),"ui-regression");folder.mkdirs();try(java.io.FileOutputStream out=new java.io.FileOutputStream(new java.io.File(folder,name+".png"))){image.compress(android.graphics.Bitmap.CompressFormat.PNG,100,out);}}catch(Exception failure){throw new RuntimeException(failure);}finally{image.recycle();}}
    private void incrementalProvider(){
        Context context=getTargetContext();android.content.ContentResolver resolver=context.getContentResolver();Uri tree=android.provider.DocumentsContract.buildTreeDocumentUri(TestMusicProvider.AUTHORITY,"root");Uri provider=tree;
        resolver.call(provider,"reset",null,null);
        List<Song> first=FolderLibrary.scan(context,Collections.singleton(tree.toString()),false,(a,b,c)->{},Collections.emptyList());check(first.size()==2&&first.get(0).duration>0,"Synthetic WAV metadata not readable");
        int initial=resolver.call(provider,"stats",null,null).getInt("reads");
        List<Song> second=FolderLibrary.scan(context,Collections.singleton(tree.toString()),false,(a,b,c)->{},first);
        check(resolver.call(provider,"stats",null,null).getInt("reads")==initial,"Unchanged scan reopened audio");
        check(context.getSharedPreferences("library",0).getInt("scan_reused",0)==2,"Unchanged scan did not reuse two songs");
        resolver.call(provider,"edit",null,null);List<Song> third=FolderLibrary.scan(context,Collections.singleton(tree.toString()),false,(a,b,c)->{},second);
        check(context.getSharedPreferences("library",0).getInt("scan_read",0)==1,"Changed file must be reread alone");
        resolver.call(provider,"remove",null,null);List<Song> fourth=FolderLibrary.scan(context,Collections.singleton(tree.toString()),false,(a,b,c)->{},third);
        check(fourth.size()==1&&context.getSharedPreferences("library",0).getString("scan_missing","[]").contains("two"),"Removed file did not appear in missing report");
        report.append("PASS Android ContentProvider incremental reads, edits and removed-file reporting\n");
    }
    private void modalPresentation(){
        for(String theme:new String[]{"light","dark"}){
            main(()->activity.getSharedPreferences("library",0).edit().putString("appearance",theme).commit());
            AppDialog[] current={null};int[] callbacks={0};EditText[] input={null};
            main(()->{input[0]=new EditText(activity);input[0].setHint("歌单名称");current[0]=new AppDialog.Builder(activity).setTitle("创建歌单").setMessage("输入名称后保存，空名称会保留弹窗。").setView(input[0]).setNegativeButton("取消",null).setPositiveButton("创建",null).create();current[0].setOnShowListener(d->current[0].getButton(DialogInterface.BUTTON_POSITIVE).setOnClickListener(v->{if(input[0].getText().length()==0){input[0].setError("请输入名称");return;}callbacks[0]++;current[0].dismiss();}));current[0].show();});settle();
            main(()->{check(input[0].getCurrentTextColor()==DialogSurface.palette(activity).text,"Modal input ignored theme");current[0].getButton(DialogInterface.BUTTON_POSITIVE).performClick();check(current[0].isShowing(),"Validation dismissed modal");input[0].setText("测试歌单");current[0].getButton(DialogInterface.BUTTON_POSITIVE).performClick();check(callbacks[0]==1,"Modal action fired incorrectly");});settle();
            main(()->current[0]=new AppDialog.Builder(activity).setTitle("选择主题").setSingleChoiceItems(new String[]{"跟随系统","浅色","深色"},1,(d,i)->callbacks[0]++).setNegativeButton("关闭",null).show());settle();screenshot("modal-choice-"+theme);main(()->current[0].dismiss());settle();
            StringBuilder message=new StringBuilder();for(int i=0;i<120;i++)message.append("歌词与诊断信息 ").append(i).append("\n");main(()->current[0]=new AppDialog.Builder(activity).setTitle("详细信息").setMessage(message).setPositiveButton("关闭",null).show());settle();main(()->{check(current[0].getButton(DialogInterface.BUTTON_POSITIVE).isShown(),"Long content hid modal action");current[0].dismiss();});settle();
            android.app.Dialog[] sheet={null};main(()->sheet[0]=BottomSheet.show(activity,"歌曲操作",body->{TextView row=BottomSheet.action(activity,body,"加入歌单",()->{});check(row.getCurrentTextColor()==DialogSurface.palette(activity).text,"Sheet row ignored theme");BottomSheet.action(activity,body,"查看歌词",()->{});}));settle();screenshot("modal-actions-"+theme);main(()->sheet[0].dismiss());settle();
            report.append("PASS ").append(theme).append(" modal input validation, callbacks, choices, long content and action sheet palette\n");
        }
    }
    private String javascript(android.webkit.WebView web,String source){
        java.util.concurrent.CountDownLatch latch=new java.util.concurrent.CountDownLatch(1);String[] result={null};main(()->web.evaluateJavascript(source,value->{result[0]=value;latch.countDown();}));try{check(latch.await(10,java.util.concurrent.TimeUnit.SECONDS),"WebView callback timed out");}catch(InterruptedException failure){throw new RuntimeException(failure);}return result[0];
    }
    private void webClick(android.webkit.WebView web,String selector){check("true".equals(javascript(web,"(()=>{const node=document.querySelector("+org.json.JSONObject.quote(selector)+");if(!node)return false;node.click();return true;})()")),"Missing shared control: "+selector);SystemClock.sleep(220);}
    private void webButton(android.webkit.WebView web,String text){check("true".equals(javascript(web,"(()=>{const root=document.querySelector('[role=dialog]')||document;const button=Array.from(root.querySelectorAll('button')).find(x=>x.textContent.trim()==="+org.json.JSONObject.quote(text)+");if(!button)return false;button.click();return true;})()")),"Missing shared action: "+text);SystemClock.sleep(260);}
    // Theme is configured only in Settings; return with the drawer open.
    private void webTheme(android.webkit.WebView web,String theme){
        check("true".equals(javascript(web,"!document.querySelector('.mv-drawer [aria-label=浅色模式],.mv-drawer [aria-label=深色模式]')")),"Sidebar exposes theme shortcut");
        webClick(web,".mv-drawer [aria-label=\"设置\"]");SystemClock.sleep(200);
        String label=theme.equals("dark")?"深色模式":"浅色模式";
        javascript(web,"Array.from(document.querySelectorAll('.mv-mobile-settings button')).find(n=>n.textContent.startsWith('"+label+"')).click();true");SystemClock.sleep(200);
        webClick(web,"[aria-label=\"关闭弹窗\"]");webClick(web,"[aria-label=\"打开侧边栏\"]");SystemClock.sleep(150);
        check(javascript(web,"document.querySelector('main').dataset.theme").contains(theme),"Settings theme did not apply");
    }
    private void webTap(android.webkit.WebView web,String selector){try{org.json.JSONArray point=new org.json.JSONArray(javascript(web,"(()=>{const r=document.querySelector("+org.json.JSONObject.quote(selector)+").getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2,innerWidth]})()"));float ratio=web.getWidth()/(float)point.getDouble(2);tap(web,(float)point.getDouble(0)*ratio,(float)point.getDouble(1)*ratio);SystemClock.sleep(300);}catch(Exception failure){throw new RuntimeException(failure);}}
    private void webListReady(android.webkit.WebView web){boolean ready=false;for(int attempt=0;attempt<40;attempt++){if("true".equals(javascript(web,"document.querySelector('.mv-song-list')?.getAttribute('aria-busy')==='false'"))){ready=true;break;}SystemClock.sleep(100);}check(ready,"List restore did not complete");}
    private void webStyle(android.webkit.WebView web,String label){
        String target=label.equals("简易")?"simple":label.equals("音乐库")?"library":"wall";
        for(int i=0;i<3;i++){
            if(javascript(web,"document.querySelector('main').dataset.style").contains(target))return;
            javascript(web,"window.styleAnimSeen=false;window.styleAnimDone=false;window.styleFrames=[];window.styleRasterColors=0;window.styleFrameUntil=performance.now()+5000;requestAnimationFrame(function sample(){const active=document.documentElement.dataset.mvStyleTransition==='true';if(active){window.styleAnimSeen=true;const c=document.querySelector('.mv-style-fragment-sweep');if(c){const tile=c.querySelector('canvas');window.styleFrames.push(tile?getComputedStyle(tile).transform:c.dataset.elapsed);if(!window.styleRasterColors){const probe=document.createElement('canvas');probe.width=16;probe.height=16;const ctx=probe.getContext('2d');for(const tile of c.querySelectorAll('canvas'))ctx.drawImage(tile,parseFloat(tile.style.left)/innerWidth*16,parseFloat(tile.style.top)/innerHeight*16,parseFloat(tile.style.width)/innerWidth*16,parseFloat(tile.style.height)/innerHeight*16);const pixels=ctx.getImageData(0,0,16,16).data,colors=new Set();for(let n=0;n<pixels.length;n+=4)if(pixels[n+3]>0)colors.add(pixels[n]+','+pixels[n+1]+','+pixels[n+2]);window.styleRasterColors=colors.size}}}else if(window.styleAnimSeen){window.styleAnimDone=true;return}if(performance.now()<window.styleFrameUntil)requestAnimationFrame(sample)});true");
            webClick(web,".mv-brand-logo");boolean finished=false;
            for(int attempt=0;attempt<50;attempt++){if("true".equals(javascript(web,"window.styleAnimDone"))){finished=true;break;}SystemClock.sleep(100);}
            check(finished,"Style icon animation did not finish");
            check("true".equals(javascript(web,"new Set(window.styleFrames).size>2&&window.styleRasterColors>5")),"Style switch lacks composited fragment motion or actual nonblank app snapshot");
        }
        check(javascript(web,"document.querySelector('main').dataset.style").contains(target),"Style icon did not cycle to "+target);
    }

    private void webName(android.webkit.WebView web,String name){check("true".equals(javascript(web,"(()=>{const input=document.querySelector('input[aria-label=\"歌单名称\"]');if(!input)return false;Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,"+org.json.JSONObject.quote(name)+");input.dispatchEvent(new Event('input',{bubbles:true}));return true;})()")),"Playlist input missing");SystemClock.sleep(150);javascript(web,"document.querySelector('[role=dialog] form').requestSubmit();true");SystemClock.sleep(500);}
    private void webDragControl(android.webkit.WebView web,String selector)throws Exception{
        org.json.JSONArray point=new org.json.JSONArray(javascript(web,"(()=>{const r=document.querySelector("+org.json.JSONObject.quote(selector)+").getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2,innerWidth]})()"));float ratio=web.getWidth()/(float)point.getDouble(2);int[] origin=new int[2];main(()->web.getLocationOnScreen(origin));float x=origin[0]+(float)point.getDouble(0)*ratio,y=origin[1]+(float)point.getDouble(1)*ratio;long now=SystemClock.uptimeMillis();pointer(now,now,MotionEvent.ACTION_DOWN,x,y);for(int i=1;i<=8;i++){SystemClock.sleep(18);pointer(now,SystemClock.uptimeMillis(),MotionEvent.ACTION_MOVE,x+72*ratio*i/8,y-32*ratio*i/8);}pointer(now,SystemClock.uptimeMillis(),MotionEvent.ACTION_UP,x+72*ratio,y-32*ratio);
    }
    private void wallTouchContracts(android.webkit.WebView web,PortablePlayerActivity preview)throws Exception{
        check("true".equals(javascript(web,"!document.querySelector('.wp-header-actions .mv-button')&&!!document.querySelector('.mv-wall-current-outline')&&getComputedStyle(document.querySelector('.mv-wall-current-outline')).zIndex==='5'&&Array.from(document.querySelectorAll('.mv-wall-card:not(.is-focus-underlay)')).every(n=>getComputedStyle(n,':before').backgroundColor.endsWith('0.34)'))")),"Wall header/dimming/foreground contour contract missing");
        for(String selector:new String[]{".wp-controls [data-wall-transport=play]",".wp-controls button:has(svg[data-icon=heart])",".wp-line[data-active=true]"}){
            javascript(web,"window.wallTouchTrace=[];window.wallTrace=event=>{const row={type:event.type,target:event.target.closest('button')?.getAttribute('aria-label')||event.target.className,id:event.pointerId,pointerType:event.pointerType,trusted:event.isTrusted,detail:event.detail,x:event.clientX,y:event.clientY,touch:event.sourceCapabilities?.firesTouchEvents};window.wallTouchTrace.push(row);queueMicrotask(()=>row.prevented=event.defaultPrevented)};for(const type of ['pointerdown','pointerup','click'])document.addEventListener(type,window.wallTrace,true);true");String before=javascript(web,"document.querySelector('.mv-wall-plane').dataset.camera"),playing=javascript(web,"document.querySelector('.wp-player').className");long haptic=(Long)field(preview,"lastHaptic");webDragControl(web,selector);SystemClock.sleep(60);
            check(!before.equals(javascript(web,"document.querySelector('.mv-wall-plane').dataset.camera")),"Cannot pan from card control "+selector);check(playing.equals(javascript(web,"document.querySelector('.wp-player').className")),"Pan triggered playback "+selector);check(haptic==(Long)field(preview,"lastHaptic"),"Pan triggered click/haptic "+selector);
            javascript(web,"window.wallDrawerImage=document.querySelector('.mv-wall-focused-art');window.wallDrawerFrames=[];window.wallDrawerUntil=performance.now()+1500;requestAnimationFrame(function sample(){const image=window.wallDrawerImage,r=image.getBoundingClientRect(),scene=document.querySelector('.mv-scene');window.wallDrawerFrames.push(image.isConnected&&image.naturalWidth>0&&r.width>100&&r.height>100&&getComputedStyle(scene).filter==='none'&&document.querySelector('.mv-cover-wall').scrollLeft===0);if(performance.now()<window.wallDrawerUntil)requestAnimationFrame(sample)});true");webTap(web,"[aria-label=打开侧边栏]");for(int wait=0;wait<15&&!"true".equals(javascript(web,"!!document.querySelector('.mv-drawer')"));wait++)SystemClock.sleep(100);check("true".equals(javascript(web,"!!document.querySelector('.mv-drawer')")),"Sidebar tap lost after control pan "+selector+" "+javascript(web,"JSON.stringify({viewport:visualViewport?{scale:visualViewport.scale,x:visualViewport.offsetLeft,y:visualViewport.offsetTop}:null,root:{w:innerWidth,h:innerHeight},hit:document.elementsFromPoint(42,80).slice(0,3).map(n=>n.className),drag:document.querySelector('.mv-cover-wall').dataset.dragging,events:window.wallTouchTrace})"));String held=javascript(web,"document.querySelector('.mv-wall-plane').dataset.camera");SystemClock.sleep(300);check(held.equals(javascript(web,"document.querySelector('.mv-wall-plane').dataset.camera")),"Wall inertia continues behind drawer");webTap(web,"[aria-label=关闭侧边栏]");SystemClock.sleep(450);check("true".equals(javascript(web,"!document.querySelector('.mv-scene').inert&&document.querySelector('.mv-wall-focused-art').naturalWidth>0")),"Drawer close lost artwork or input");check("true".equals(javascript(web,"window.wallDrawerFrames.length>12&&window.wallDrawerFrames.every(Boolean)")),"Drawer transition replaced or hid decoded wall pixels");
            if("true".equals(javascript(web,"!document.querySelector('.wp-dock-meter').hidden")))webTap(web,".wp-dock-meter");webTap(web,".mv-now");SystemClock.sleep(750);javascript(web,"for(const type of ['pointerdown','pointerup','click'])document.removeEventListener(type,window.wallTrace,true);true");
        }
        org.json.JSONArray edge=new org.json.JSONArray(javascript(web,"(()=>{const r=document.querySelector('[aria-label=打开侧边栏]').getBoundingClientRect();return [r.left+1,r.top+r.height/2,innerWidth]})()"));float edgeRatio=web.getWidth()/(float)edge.getDouble(2);tap(web,(float)edge.getDouble(0)*edgeRatio,(float)edge.getDouble(1)*edgeRatio);SystemClock.sleep(400);check("true".equals(javascript(web,"!!document.querySelector('.mv-drawer')")),"Button press shrink cancelled a valid edge tap");webTap(web,"[aria-label=关闭侧边栏]");SystemClock.sleep(400);
        webTap(web,"[aria-label=音乐墙设置]");check("true".equals(javascript(web,"document.querySelector('.mv-modal h2').textContent==='音乐墙'")),"Wall settings title differs");webTap(web,"[aria-label=关闭弹窗]");
        report.append("PASS real Android drag from play/favorite/lyric, no click/haptic, next sidebar tap, frozen drawer camera, dimmed cards/top contour and cleaned header\n");
    }
    private void wallVersionContracts(android.webkit.WebView web,Activity preview,Song first)throws Exception{
        main(()->{PlaybackService service=(PlaybackService)field(preview,"playback");if(service.isPlaying())service.toggle();StringBuilder raw=new StringBuilder();for(int index=0;index<30;index++){raw.append(String.format(java.util.Locale.ROOT,"[00:%02d.000]音乐墙测试歌词第%d行，确认缩放之后依然清晰完整\n",index,index+1));raw.append(String.format(java.util.Locale.ROOT,"[00:%02d.000]Translation line %d\n",index,index+1));}service.current().lyricsRaw=raw.toString();service.current().lyricsPrepared=true;service.seek(0);});SystemClock.sleep(700);
        check("true".equals(javascript(web,"(()=>{const wall=document.querySelector('.mv-cover-wall').getBoundingClientRect(),root=document.querySelector('main').getBoundingClientRect();return Math.abs(wall.left-root.left)<1&&Math.abs(wall.top-root.top)<1&&Math.abs(wall.width-root.width)<1&&Math.abs(wall.height-root.height)<1&&!document.querySelector('.mv-wall-zoom')})()")),"Wall is not a full-surface canvas");
        main(()->{int[] origin=new int[2];web.getLocationOnScreen(origin);check(origin[1]==0,"Wall host still reserves a status-bar strip: y="+origin[1]+" wall="+field(preview,"wallChrome"));});
        check("true".equals(javascript(web,"!!document.querySelector('[aria-label=\"音乐墙设置\"] svg[data-icon=wallSettings]')")),"Wall settings button uses the wrong icon");
        check("true".equals(javascript(web,"(()=>{const r=document.querySelector('.mv-wall-dock').getBoundingClientRect(),safe=parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--mv-safe-left'))||0;return Math.abs(r.left-safe-14)<1&&r.bottom<=innerHeight})()")),"Wall dock is not anchored lower left");
        javascript(web,"window.wallOriginalCover=document.querySelector('.mv-wall-card[data-wall-id=\""+first.id+"\"] img');document.querySelector('.mv-wall-card[data-wall-id=\""+first.id+"\"]').click();true");SystemClock.sleep(900);
        check("true".equals(javascript(web,"window.wallOriginalCover.isConnected&&document.querySelector('.mv-wall-focused-art')?.naturalWidth>0")),"Wall focus replaced the loaded image");check("true".equals(javascript(web,"document.querySelector('.mv-wall-focused-art').naturalWidth===2048&&document.querySelector('.mv-wall-focused-art').naturalHeight===1536&&document.querySelector('.mv-wall-focused-art').src.includes('quality=original')")),"Expanded artwork still uses a thumbnail");
        check("true".equals(javascript(web,"(()=>{const button=document.querySelector('.wp-controls [data-wall-transport=play]').getBoundingClientRect(),controls=document.querySelector('.wp-controls').getBoundingClientRect();return Math.abs(button.left-controls.left)<1})()")),"Wall play is not in the lower-left slot");
        check("true".equals(javascript(web,"!!document.querySelector('.wp-translation-toggle')&&!!document.querySelector('.wp-line small')")),"Phone wall did not show bilingual lyrics");
        wallTouchContracts(web,(PortablePlayerActivity)preview);
        webTap(web,".wp-translation-toggle");check("true".equals(javascript(web,"!document.querySelector('.wp-line small')")),"Phone translation toggle did not hide translation");
        javascript(web,"window.pressScales=[];window.pressUntil=performance.now()+1600;requestAnimationFrame(function sample(){const b=document.querySelector('.wp-translation-toggle');window.pressScales.push(parseFloat(getComputedStyle(b).scale)||1);if(performance.now()<window.pressUntil)requestAnimationFrame(sample)});true");webTap(web,".wp-translation-toggle");SystemClock.sleep(350);
        check("true".equals(javascript(web,"!!document.querySelector('.wp-line small')&&window.pressScales.some(x=>x>1.1)&&window.pressScales.some(x=>x<.99)")),"Phone spring overshoot or bilingual return missing: "+javascript(web,"JSON.stringify(window.pressScales)"));
        for(int scale:new int[]{60,100,120}){
            webClick(web,"[aria-label='音乐墙设置']");check("true".equals(javascript(web,"document.querySelector('[role=dialog]').getAttribute('aria-label')==='音乐墙'")),"Wall settings entry opens the wrong panel");check("true".equals(javascript(web,"!!document.querySelector('[role=slider][aria-label=\"显示比例\"]')&&document.querySelectorAll('.wp-settings .mv-slider-mark').length===7&&!document.querySelector('.wp-scale-stops')")),"Wall scale settings incomplete");
            check("true".equals(javascript(web,"!document.querySelector('.wp-settings').textContent.includes('播放模式')&&!document.querySelector('.wp-settings').textContent.includes('应用设置')")),"Phone wall settings scope differs from Mac");
            webScale(web,scale);webClick(web,"[aria-label='关闭弹窗']");SystemClock.sleep(500);
            check("true".equals(javascript(web,"Math.abs(Number(document.querySelector('.mv-cover-wall').dataset.wallScale)-"+(scale/100.0)+")<.01")),"Wall settings did not change scale");
            check("true".equals(javascript(web,"(()=>{const card=document.querySelector('.mv-wall-focused'),lyrics=card?.querySelector('.wp-lyrics'),lines=card?.querySelectorAll('.wp-line');if(!lyrics||lines.length<3)return false;const r=lyrics.getBoundingClientRect();const current=lyrics.querySelector('[data-active=true]');if(!current)return false;const b=current.getBoundingClientRect();return b.height>=12&&b.top>=r.top-2&&b.bottom<=r.bottom+2&&getComputedStyle(current.querySelector('.lyric-content')).webkitLineClamp==='none'})()")),"Wall lyrics collapse or clip while zooming");screenshot("wall-v2-phone-"+scale);if(scale==100){android.graphics.Bitmap raster=getUiAutomation().takeScreenshot();int white=0,total=0;try{for(int y=raster.getHeight()*8/100;y<raster.getHeight()*24/100;y+=4)for(int x=16;x<raster.getWidth()*95/100;x+=4){int color=raster.getPixel(x,y);total++;if(android.graphics.Color.red(color)>248&&android.graphics.Color.green(color)>248&&android.graphics.Color.blue(color)>248)white++;}check(white<total*.025,"Wall backdrop sampling retained white stale rectangles after drawer/zoom: "+white+"/"+total);}finally{raster.recycle();}}
        }
        webClick(web,"[aria-label=音乐墙设置]");
        try{org.json.JSONArray track=new org.json.JSONArray(javascript(web,"(()=>{const r=document.querySelector('.wp-settings [role=slider]').getBoundingClientRect();return [r.x,r.y+r.height/2,r.width,innerWidth]})()"));float ratio=web.getWidth()/(float)track.getDouble(3),x=(float)track.getDouble(0)*ratio,y=(float)track.getDouble(1)*ratio,w=(float)track.getDouble(2)*ratio;int[] origin=new int[2];main(()->web.getLocationOnScreen(origin));long now=SystemClock.uptimeMillis();pointer(now,now,MotionEvent.ACTION_DOWN,origin[0]+x+w/3,origin[1]+y);SystemClock.sleep(80);check("true".equals(javascript(web,"(()=>{const n=document.querySelector('.wp-settings [role=slider]');return getComputedStyle(n).outlineStyle==='none'&&[n,...n.querySelectorAll('*')].every(x=>getComputedStyle(x).webkitTapHighlightColor==='rgba(0, 0, 0, 0)')})()")),"Scale stop still flashes a rectangular touch highlight");screenshot("wall-scale-node-pressed");for(int step=1;step<=5;step++){SystemClock.sleep(20);pointer(now,SystemClock.uptimeMillis(),MotionEvent.ACTION_MOVE,origin[0]+x+w*(1f/3+(2f/60-1f/3)*step/5),origin[1]+y);}pointer(now,SystemClock.uptimeMillis(),MotionEvent.ACTION_UP,origin[0]+x+w*2/60,origin[1]+y);}catch(Exception failure){throw new RuntimeException(failure);}
        SystemClock.sleep(300);check("true".equals(javascript(web,"Math.abs(Number(document.querySelector('.mv-cover-wall').dataset.wallScale)-.62)<.011")),"Phone scale slider cannot choose 62 percent");webScale(web,100);webClick(web,"[aria-label=关闭弹窗]");
        report.append("PASS continuous scale 62 percent, compact Mac-like wall settings, translation toggle and button spring overshoot\n");

        webClick(web,".mv-wall-focused [aria-label='展开播放器']");SystemClock.sleep(750);check("true".equals(javascript(web,"(()=>{const r=document.querySelector('.mv-wall-focused').getBoundingClientRect();return Math.abs(r.left)<2&&Math.abs(r.top)<2&&Math.abs(r.width-innerWidth)<2&&Math.abs(r.height-innerHeight)<2&&getComputedStyle(document.querySelector('[aria-label=\"音乐墙设置\"]')).visibility==='hidden'})()")),"Expanded wall player does not fill the viewport");playbackIconCenters(web);screenshot("wall-v2-expanded-phone");main(preview::onBackPressed);SystemClock.sleep(700);
        check("true".equals(javascript(web,"document.querySelector('main').dataset.wallExpanded==='false' && !!document.querySelector('.mv-wall-focused')")),"Back must collapse expansion before closing focus");
        main(()->preview.setRequestedOrientation(android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE));SystemClock.sleep(1300);dismissImmersiveHint();
        check("true".equals(javascript(web,"innerWidth>innerHeight && document.querySelector('main').dataset.input==='touch'")),"Wall rotation switched input family");if(android.os.Build.VERSION.SDK_INT>=30)check(!web.getRootWindowInsets().isVisible(android.view.WindowInsets.Type.statusBars())&&!web.getRootWindowInsets().isVisible(android.view.WindowInsets.Type.navigationBars()),"Landscape wall must hide both system bars");check("true".equals(javascript(web,"(()=>{const card=document.querySelector('.mv-wall-focused').getBoundingClientRect();return card.left>=0&&card.top>=0&&card.right<=innerWidth+2&&card.bottom<=innerHeight+2})()")),"Landscape wall focus leaves visible bounds");screenshot("wall-v2-landscape");
        webClick(web,".mv-wall-focused [aria-label='展开播放器']");SystemClock.sleep(650);check("true".equals(javascript(web,"Math.abs(document.querySelector('.mv-wall-focused').getBoundingClientRect().height-innerHeight)<2")),"Landscape expanded player is not full screen");screenshot("wall-v2-expanded-landscape");main(preview::onBackPressed);SystemClock.sleep(500);main(()->preview.setRequestedOrientation(android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT));SystemClock.sleep(1200);
        main(preview::onBackPressed);SystemClock.sleep(400);check("true".equals(javascript(web,"!document.querySelector('.mv-wall-focused')")),"Wall close leaves a ghost player");
        javascript(web,"const card=Array.from(document.querySelectorAll('.mv-wall-card')).find(x=>x.dataset.wallId!=='"+first.id+"');window.wallPrevious=document.querySelector('.mv-now strong').textContent;window.wallPreview=card.querySelector('strong').textContent;card.click();true");SystemClock.sleep(700);check("true".equals(javascript(web,"document.querySelector('.mv-now strong').textContent===window.wallPrevious&&document.querySelector('.wp-heading h1').textContent===window.wallPreview")),"Wall preview must not change playback");main(preview::onBackPressed);SystemClock.sleep(350);
        check("true".equals(javascript(web,"getComputedStyle(document.querySelector('.mv-wall-plane')).transform==='none'&&getComputedStyle(document.querySelector('.mv-wall-plane')).willChange==='auto'")),"Wall still uses a promoted world plane");
        for(int step=0;step<12;step++){
            javascript(web,"(()=>{const nodes=Array.from(document.querySelectorAll('.mv-wall-card')).filter(n=>{const r=n.getBoundingClientRect();return !n.classList.contains('is-focus-underlay')&&r.right>40&&r.left<innerWidth-40&&r.bottom>80&&r.top<innerHeight-100});const target=nodes["+step+"%nodes.length];target?.focus();target?.click();return true;})()");SystemClock.sleep(70);
            check("true".equals(javascript(web,"Array.from(document.querySelectorAll('.mv-cover-wall,.mv-wall-focused')).every(n=>n.scrollLeft===0&&n.scrollTop===0)")),"Focus scrolled wall canvas");
            android.graphics.Bitmap frame=getUiAutomation().takeScreenshot();check(frame!=null,"Missing wall raster sample");int blank=0,samples=0;
            try{for(int y=frame.getHeight()/10;y<frame.getHeight()*9/10;y+=12)for(int x=frame.getWidth()/10;x<frame.getWidth()*9/10;x+=12){int color=frame.getPixel(x,y);samples++;if(Math.abs(android.graphics.Color.red(color)-14)<4&&Math.abs(android.graphics.Color.green(color)-25)<4&&Math.abs(android.graphics.Color.blue(color)-21)<4)blank++;}check(blank<samples*.65,"Full wall raster vanished during rapid selection at step "+step);}finally{frame.recycle();}
        }
        screenshot("wall-rapid-raster-final");
        report.append("PASS Android rapid selection raster coverage and unpromoted viewport wall\n");
        report.append("PASS wall full-bleed and settings, 60/100/120 lyrics, expanded/back, rotation, close and preview\n");
    }
    private void menuContracts(android.webkit.WebView web)throws Exception{
        org.json.JSONArray rect=new org.json.JSONArray(javascript(web,"(()=>{const r=Array.from(document.querySelectorAll('.mv-song')).find(x=>x.getBoundingClientRect().top>=document.querySelector('.mv-song-list').getBoundingClientRect().top).getBoundingClientRect();return [r.left+100,r.top+r.height/2,innerWidth]})()"));float ratio=web.getWidth()/(float)rect.getDouble(2),x=(float)rect.getDouble(0)*ratio,y=(float)rect.getDouble(1)*ratio;int[] origin=new int[2];main(()->web.getLocationOnScreen(origin));long down=SystemClock.uptimeMillis();pointer(down,down,0,origin[0]+x,origin[1]+y);SystemClock.sleep(80);pointer(down,SystemClock.uptimeMillis(),2,origin[0]+x+2*ratio,origin[1]+y+2*ratio);SystemClock.sleep(560);pointer(down,SystemClock.uptimeMillis(),1,origin[0]+x+2*ratio,origin[1]+y+2*ratio);SystemClock.sleep(200);
        check("true".equals(javascript(web,"!!document.querySelector('[data-mv-menu=list] [role=menuitem]')")),"Small touch jitter must retain long-press menu");
        check("true".equals(javascript(web,"(()=>{const menu=document.querySelector('[data-mv-menu=list]'),first=menu.querySelector('[role=menuitem]');first.focus();first.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowDown',bubbles:true,cancelable:true}));return document.activeElement.textContent==='加入歌单'})()")),"Touch menu keyboard navigation failed");
        javascript(web,"document.activeElement.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true}));true");SystemClock.sleep(200);check(javascript(web,"document.querySelector('[role=dialog]').getAttribute('aria-label')").contains("加入歌单"),"Menu Enter did not open playlist picker");webClick(web,"[aria-label='关闭弹窗']");
        down=SystemClock.uptimeMillis();pointer(down,down,0,origin[0]+x,origin[1]+y);SystemClock.sleep(70);pointer(down,SystemClock.uptimeMillis(),2,origin[0]+x,origin[1]+y-40*ratio);SystemClock.sleep(550);pointer(down,SystemClock.uptimeMillis(),1,origin[0]+x,origin[1]+y-40*ratio);SystemClock.sleep(150);check("true".equals(javascript(web,"!document.querySelector('[role=dialog]')")),"Scrolling must cancel long-press menu");
        report.append("PASS actual long-press jitter tolerance, scroll cancel and shared menu keyboard activation\n");
    }
    private void sliderContracts(android.webkit.WebView web,Activity preview)throws Exception{
        main(()->{PlaybackService service=(PlaybackService)field(preview,"playback");if(service.isPlaying())service.toggle();service.seek(0);});SystemClock.sleep(700);
        check("true".equals(javascript(web,"!!document.querySelector('.mv-dock [role=slider][data-mv-component=slider]') && !document.querySelector('.mv-dock input[type=range]')")),"Seek must use the MiniVoice slider");
        org.json.JSONArray bounds=new org.json.JSONArray(javascript(web,"(()=>{const r=document.querySelector('.mv-dock [role=slider]').getBoundingClientRect();return [r.left,r.width,r.top+r.height/2,innerWidth]})()"));float ratio=web.getWidth()/(float)bounds.getDouble(3),left=(float)bounds.getDouble(0)*ratio,width=(float)bounds.getDouble(1)*ratio,y=(float)bounds.getDouble(2)*ratio;int[] origin=new int[2];main(()->web.getLocationOnScreen(origin));long down=SystemClock.uptimeMillis();pointer(down,down,0,origin[0]+left+width*.25f,origin[1]+y);SystemClock.sleep(80);pointer(down,SystemClock.uptimeMillis(),2,origin[0]+left+width*.75f,origin[1]+y);SystemClock.sleep(700);
        check(Double.parseDouble(javascript(web,"Number(document.querySelector('.mv-dock [role=slider]').getAttribute('aria-valuenow'))"))>500,"Polling moved a held seek thumb back");main(()->check(((PlaybackService)field(preview,"playback")).position()<150,"Seek preview changed playback before release"));
        pointer(down,SystemClock.uptimeMillis(),1,origin[0]+left+width*.75f,origin[1]+y);SystemClock.sleep(700);main(()->check(((PlaybackService)field(preview,"playback")).position()>500,"Released seek slider did not reach playback service"));
        int[] committed={0};main(()->committed[0]=((PlaybackService)field(preview,"playback")).position());down=SystemClock.uptimeMillis();pointer(down,down,0,origin[0]+left+width*.25f,origin[1]+y);SystemClock.sleep(80);pointer(down,SystemClock.uptimeMillis(),3,origin[0]+left+width*.25f,origin[1]+y);SystemClock.sleep(300);main(()->check(Math.abs(((PlaybackService)field(preview,"playback")).position()-committed[0])<150,"Canceled seek must not commit preview"));
        javascript(web,"const slider=document.querySelector('.mv-dock [role=slider]');slider.dispatchEvent(new KeyboardEvent('keydown',{key:'Home',bubbles:true,cancelable:true}));slider.dispatchEvent(new KeyboardEvent('keyup',{key:'Home',bubbles:true,cancelable:true}));true");SystemClock.sleep(500);main(()->check(((PlaybackService)field(preview,"playback")).position()<150,"Slider keyboard commit failed"));
        screenshot("shared-custom-slider");report.append("PASS custom seek held against polling, release commit, cancel and keyboard\n");
    }
    private void customScrollContracts(android.webkit.WebView web)throws Exception{
        javascript(web,"document.querySelector('.mv-song-list').scrollTop=500;true");SystemClock.sleep(150);
        check("true".equals(javascript(web,"!!document.querySelector('.mv-list-shell>.mv-custom-scroll-rail.is-visible') && getComputedStyle(document.querySelector('.mv-song-list'),'::-webkit-scrollbar').display==='none'")),"Custom scrollbar must replace browser scrollbar and reveal on scroll: "+javascript(web,"JSON.stringify({rails:Array.from(document.querySelectorAll('.mv-custom-scroll-rail')).map(x=>({class:x.className,hidden:x.hidden})),scroll:document.querySelector('.mv-song-list').scrollTop,css:getComputedStyle(document.querySelector('.mv-song-list')).scrollbarWidth,errors:document.querySelector('.mv-error')?.textContent})"));
        SystemClock.sleep(1000);check("true".equals(javascript(web,"!document.querySelector('.mv-list-shell>.mv-custom-scroll-rail').classList.contains('is-visible')")),"Idle custom scrollbar did not hide");
        javascript(web,"document.querySelector('.mv-song-list').scrollTop=600;true");SystemClock.sleep(100);
        org.json.JSONArray rect=new org.json.JSONArray(javascript(web,"(()=>{const r=document.querySelector('.mv-list-shell>.mv-custom-scroll-rail .mv-custom-scroll-thumb').getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2,innerWidth]})()"));
        float ratio=web.getWidth()/(float)rect.getDouble(2),x=(float)rect.getDouble(0)*ratio,y=(float)rect.getDouble(1)*ratio;int[] origin=new int[2];main(()->web.getLocationOnScreen(origin));long down=SystemClock.uptimeMillis();pointer(down,down,0,origin[0]+x,origin[1]+y);for(int j=1;j<=8;j++){SystemClock.sleep(20);pointer(down,SystemClock.uptimeMillis(),2,origin[0]+x,origin[1]+y+j*12*ratio);}pointer(down,SystemClock.uptimeMillis(),1,origin[0]+x,origin[1]+y+96*ratio);SystemClock.sleep(150);
        check(Double.parseDouble(javascript(web,"document.querySelector('.mv-song-list').scrollTop"))>1100,"Dragging the custom thumb did not move content");
        check("true".equals(javascript(web,"(()=>{const view=document.querySelector('.mv-song-list'),thumb=document.querySelector('.mv-list-shell>.mv-custom-scroll-rail .mv-custom-scroll-thumb');thumb.dispatchEvent(new KeyboardEvent('keydown',{key:'End',bubbles:true,cancelable:true}));return Math.abs(view.scrollTop-(view.scrollHeight-view.clientHeight))<2})()")),"Scrollbar End key must reach content end");
        javascript(web,"document.querySelector('.mv-list-shell>.mv-custom-scroll-rail .mv-custom-scroll-thumb').dispatchEvent(new KeyboardEvent('keydown',{key:'Home',bubbles:true,cancelable:true}));true");SystemClock.sleep(150);
        report.append("PASS custom scrollbar hide/reveal, real touch drag, keyboard endpoints\n");
    }
    private void sheetDragContracts(android.webkit.WebView web)throws Exception{
        webClick(web,"[aria-label='播放模式']");SystemClock.sleep(300);
        for(int variant=0;variant<3;variant++){
            org.json.JSONArray hit=new org.json.JSONArray(javascript(web,"(()=>{const r=document.querySelector('[data-mv-component=sheet-handle]').getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2,innerWidth]})()"));
            float ratio=web.getWidth()/(float)hit.getDouble(2),x=(float)hit.getDouble(0)*ratio,y=(float)hit.getDouble(1)*ratio;int[] origin=new int[2];main(()->web.getLocationOnScreen(origin));x+=origin[0];y+=origin[1];
            int distance=variant==0?35:variant==1?80:140;long down=SystemClock.uptimeMillis();pointer(down,down,MotionEvent.ACTION_DOWN,x,y);
            for(int step=1;step<=5;step++){SystemClock.sleep(25);pointer(down,SystemClock.uptimeMillis(),MotionEvent.ACTION_MOVE,x,y+distance*ratio*step/5);}
            SystemClock.sleep(170);pointer(down,SystemClock.uptimeMillis(),variant==1?MotionEvent.ACTION_CANCEL:MotionEvent.ACTION_UP,x,y+distance*ratio);SystemClock.sleep(350);
            if(variant<2)check("true".equals(javascript(web,"!!document.querySelector('[role=dialog]')&&!document.querySelector('[data-sheet-dragging]')&&Math.abs(parseFloat(getComputedStyle(document.querySelector('.mv-modal')).translate.split(' ')[1])||0)<1")),"Short/cancelled sheet drag did not return");
            else check("true".equals(javascript(web,"!document.querySelector('[role=dialog]')&&!document.querySelector('[data-surface-exit]')")),"Long sheet drag did not dismiss");
        }
        report.append("PASS real sheet handle pull, return, pointer cancel and dismissal\n");
    }
    private void dismissImmersiveHint(){
        android.view.accessibility.AccessibilityNodeInfo root=getUiAutomation().getRootInActiveWindow();if(root==null)return;
        for(String text:new String[]{"Got it","知道了"})for(android.view.accessibility.AccessibilityNodeInfo node:root.findAccessibilityNodeInfosByText(text))if(node.isClickable()){node.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK);SystemClock.sleep(200);return;}
    }
    private void chromeContracts()throws Exception{
        PortablePlayerActivity preview=(PortablePlayerActivity)startActivitySync(new Intent(getTargetContext(),PortablePlayerActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK));
        android.webkit.WebView web=(android.webkit.WebView)field(preview,"web");SystemClock.sleep(1200);
        java.lang.reflect.Method apply=PortablePlayerActivity.class.getDeclaredMethod("applyChrome",org.json.JSONObject.class);apply.setAccessible(true);
        for(String style:new String[]{"wall","library","simple"})for(String theme:new String[]{"light","dark"}){
            org.json.JSONObject state=new org.json.JSONObject().put("pages",new org.json.JSONObject().put("appearance",new org.json.JSONObject().put("style",style).put("theme",theme)));
            main(()->{try{apply.invoke(preview,state);}catch(Exception e){throw new RuntimeException(e);}});SystemClock.sleep(200);
            int appearance=preview.getWindow().getDecorView().getSystemUiVisibility();boolean darkIcons=(appearance&android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR)!=0;
            check(darkIcons==(!style.equals("wall")&&theme.equals("light")),"System status icon palette mismatch "+style+"/"+theme);
        }
        for(int orientation:new int[]{android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE,android.content.pm.ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE}){
            main(()->preview.setRequestedOrientation(orientation));SystemClock.sleep(1000);dismissImmersiveHint();
            final int rotation=preview.getWindowManager().getDefaultDisplay().getRotation();String side=rotation==android.view.Surface.ROTATION_270?"left":"right";
            check("true".equals(javascript(web,"parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--mv-safe-"+side+"'))>=16")),"Hidden navigation edge lost rotated clearance");
        }
        main(()->preview.setRequestedOrientation(android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT));main(preview::finish);
        report.append("PASS three styles/light-dark native status icon appearance and both landscape navigation edges\n");
    }
    private void systemBarContracts(PortablePlayerActivity preview,android.webkit.WebView web)throws Exception{
        for(int orientation:new int[]{android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE,android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT}){
            main(()->preview.setRequestedOrientation(orientation));SystemClock.sleep(1000);dismissImmersiveHint();
            check("true".equals(javascript(web,"(()=>{const root=document.querySelector('main'),s=getComputedStyle(root),global=getComputedStyle(document.documentElement),safe=n=>parseFloat(global.getPropertyValue('--mv-safe-'+n))||0,dock=document.querySelector('.mv-dock').getBoundingClientRect();return Math.abs(parseFloat(s.paddingTop)-safe('top')-parseFloat(s.getPropertyValue('--mv-page-y')))<1&&Math.abs(parseFloat(s.paddingBottom)-safe('bottom')-(innerWidth>innerHeight?8:12))<1&&dock.bottom<=innerHeight-safe('bottom')+1&&dock.right<=innerWidth-safe('right')+1&&dock.left>=safe('left')-1})()")),"Library/simple content overlaps system bars or doubles insets");
            android.view.WindowInsets insets=web.getRootWindowInsets();check(insets!=null,"Missing Android window insets");
            if(android.os.Build.VERSION.SDK_INT>=30){boolean landscape=orientation==android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE;check(insets.isVisible(android.view.WindowInsets.Type.statusBars())!=landscape&&insets.isVisible(android.view.WindowInsets.Type.navigationBars())!=landscape,"Landscape must hide both system bars and portrait restore both");}
            int expectedTop,expectedBottom;if(android.os.Build.VERSION.SDK_INT>=30){android.graphics.Insets bars=insets.getInsets(android.view.WindowInsets.Type.systemBars()|android.view.WindowInsets.Type.displayCutout());expectedTop=bars.top;expectedBottom=bars.bottom;}else{expectedTop=insets.getSystemWindowInsetTop();expectedBottom=Math.min(insets.getSystemWindowInsetBottom(),insets.getStableInsetBottom());}
            float density=getTargetContext().getResources().getDisplayMetrics().density;
            org.json.JSONArray actual=new org.json.JSONArray(javascript(web,"(()=>{const s=getComputedStyle(document.documentElement);return [parseFloat(s.getPropertyValue('--mv-safe-top'))||0,parseFloat(s.getPropertyValue('--mv-safe-bottom'))||0]})()"));
            check(Math.abs(actual.getDouble(0)-expectedTop/density)<1&&Math.abs(actual.getDouble(1)-expectedBottom/density)<1,"Host did not publish actual system-bar insets");
        }
    }
    private void componentContracts(android.webkit.WebView web)throws Exception{
        check("true".equals(javascript(web,"document.querySelector('main').dataset.input==='touch' && document.querySelector('main').dataset.reference==='android'")),"Android must use mobile touch components");
        check("true".equals(javascript(web,"Array.from(document.querySelectorAll('[data-mv-component=action-button]')).filter(x=>x.getClientRects().length&&x.getBoundingClientRect().height>0).every(x=>x.getBoundingClientRect().width>=44&&x.getBoundingClientRect().height>=44)")),"Touch actions must retain 44px targets");
        javascript(web,"Object.assign(document.querySelector('main').style,{width:'1024px',height:'1366px'});true");SystemClock.sleep(150);
        check("true".equals(javascript(web,"document.querySelector('main').dataset.device==='tablet' && document.querySelector('main').dataset.input==='touch' && document.querySelector('main').dataset.dialogPlacement==='center'")),"Tablet must remain mobile with adapted dialog placement");
        webClick(web,"[aria-label='播放模式']");
        check("true".equals(javascript(web,"(()=>{const button=document.querySelector('[role=dialog] button');let reached=false;button.addEventListener('keydown',()=>{reached=true;},{once:true});button.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowRight',bubbles:true,cancelable:true}));return reached})()")),"Dialog must let ordinary keys reach custom controls");
        check("true".equals(javascript(web,"(()=>{const root=document.querySelector('[role=dialog]'),nodes=Array.from(root.querySelectorAll('button')).filter(x=>!x.disabled&&x.getClientRects().length);nodes.at(-1).focus();window.dispatchEvent(new KeyboardEvent('keydown',{key:'Tab',bubbles:true,cancelable:true}));return document.activeElement===nodes[0]})()")),"Dialog Tab must include action buttons and wrap focus");
        javascript(web,"window.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true}));true");SystemClock.sleep(150);
        check("true".equals(javascript(web,"!document.querySelector('[role=dialog]')")),"Escape must dismiss only the active dialog");
        javascript(web,"Object.assign(document.querySelector('main').style,{width:'',height:''});true");SystemClock.sleep(150);
        report.append("PASS mobile/desktop component contract, tablet touch profile, dialog focus and Escape\n");
    }
    private void mobileCollections(android.webkit.WebView web,Context context,List<Song> tracks,Activity preview)throws Exception{
        String name="UI-collections-"+SystemClock.uptimeMillis(),renamed=name+"-renamed",copied=name+"-copy";android.content.SharedPreferences prefs=context.getSharedPreferences("library",0);
        webClick(web,"[aria-label=\"打开侧边栏\"]");check("true".equals(javascript(web,"(()=>{const b=Array.from(document.querySelectorAll('.mv-drawer nav button')).find(x=>x.textContent.trim()==='新建歌单');b.click();return true;})()")),"Create playlist entry missing");SystemClock.sleep(180);webName(web,name);check(prefs.getStringSet("playlists",Collections.emptySet()).contains(name),"Shared create did not persist");
        org.json.JSONArray ids=new org.json.JSONArray();for(int i=0;i<30;i++)ids.put(Long.toString(tracks.get(i).id));PortableLibraryActions.execute(preview,tracks,"addManyToPlaylist",new org.json.JSONObject().put("playlist",name).put("ids",ids));
        SystemClock.sleep(600);webClick(web,"[aria-label=\"打开侧边栏\"]");check("true".equals(javascript(web,"(()=>{Array.from(document.querySelectorAll('.mv-drawer nav button')).find(x=>x.textContent.trim()==="+org.json.JSONObject.quote(name)+").click();return true;})()")),"New playlist navigation missing");SystemClock.sleep(300);
        webListReady(web);
        javascript(web,"document.querySelector('.mv-song-list').scrollTop=320;true");SystemClock.sleep(400);String before=javascript(web,"document.querySelector('.mv-song-list').scrollTop");webClick(web,"[aria-label=\"歌单操作\"]");webButton(web,"重命名歌单");webName(web,renamed);
        check(prefs.getStringSet("playlists",Collections.emptySet()).contains(renamed)&&!prefs.getStringSet("playlists",Collections.emptySet()).contains(name),"Shared rename did not migrate name");check(prefs.getStringSet("playlist_"+renamed,Collections.emptySet()).size()==30,"Shared rename lost tracks");webListReady(web);check(near(before,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Shared playlist rename lost anchor: "+before+" -> "+javascript(web,"document.querySelector('.mv-song-list').scrollTop"));
        webClick(web,"[aria-label=\"选择歌曲\"]");javascript(web,"document.querySelectorAll('.mv-song')[0].click();document.querySelectorAll('.mv-song')[1].click();true");SystemClock.sleep(180);check(javascript(web,"document.querySelector('.mv-selection-bar').textContent").contains("2 首"),"Shared multi-select failed");
        webButton(web,"批量操作");webButton(web,"加入歌单");webButton(web,"＋ 新建歌单");webName(web,copied);check(prefs.getStringSet("playlist_"+copied,Collections.emptySet()).size()==2,"Shared batch playlist creation lost selection");
        webButton(web,"批量操作");webButton(web,"从此歌单移除");webButton(web,"移除");check(prefs.getStringSet("playlist_"+renamed,Collections.emptySet()).size()==28,"Shared batch remove failed");webButton(web,"完成");
        webClick(web,"[aria-label=\"歌单操作\"]");webButton(web,"删除歌单");webButton(web,"删除");check(!prefs.getStringSet("playlists",Collections.emptySet()).contains(renamed)&&prefs.getStringSet("playlists",Collections.emptySet()).contains(copied),"Shared deletion affected wrong playlist");
        // Read-only information/lyrics actions use the authorized library, not a filesystem path supplied by JS.
        javascript(web,"window.searchControlNode=document.querySelector('.mv-search-control');true");webClick(web,"button[aria-label=\"搜索音乐\"]");check("true".equals(javascript(web,"document.querySelector('.mv-search-control')===window.searchControlNode&&document.querySelector('.mv-search-control').getBoundingClientRect().width>200")),"Search did not morph the existing control");javascript(web,"(()=>{const input=document.querySelector('input[aria-label=\"搜索音乐\"]');Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,'000 Test');input.dispatchEvent(new Event('input',{bubbles:true}));return true;})()");SystemClock.sleep(500);javascript(web,"document.querySelector('.mv-song').dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true}));true");SystemClock.sleep(180);webButton(web,"歌曲信息");screenshot("shared-song-info");check(javascript(web,"document.querySelector('.mv-song-info').textContent").contains("000 Test"),"Shared song information missing: "+javascript(web,"document.querySelector('.mv-song-info')?.textContent")+" "+javascript(web,"document.querySelector('.mv-section-title')?.textContent"));webClick(web,"[aria-label=\"关闭弹窗\"]");
        javascript(web,"document.querySelector('.mv-song').dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true}));true");SystemClock.sleep(180);webButton(web,"查看歌词");SystemClock.sleep(600);check(javascript(web,"document.querySelector('.mv-raw-lyrics').textContent").contains("Translation"),"Shared lyric detail lost translation");check("true".equals(javascript(web,"!Array.from(document.querySelectorAll('.mv-modal button')).some(n=>n.textContent.includes('编辑'))")),"Phone lyrics view unexpectedly exposes editing");webClick(web,"[aria-label=\"关闭弹窗\"]");
        javascript(web,"(()=>{const input=document.querySelector('input[aria-label=\"搜索音乐\"]');Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,'');input.dispatchEvent(new Event('input',{bubbles:true}));return true;})()");SystemClock.sleep(350);webClick(web,"button[aria-label=\"收起搜索\"]");
        webClick(web,"[aria-label=\"打开侧边栏\"]");webClick(web,"[aria-label=\"设置\"]");SystemClock.sleep(400);check("true".equals(javascript(web,"!!document.querySelector('[aria-label=\"包含子文件夹\"]')")),"Shared folder settings did not load");check(javascript(web,"document.querySelector('.mv-mobile-settings').textContent").contains("导出诊断报告"),"Shared diagnostic export entry missing");screenshot("shared-phone-settings");
        webClick(web,"[aria-label=查看缓存用量]");check(javascript(web,"document.querySelector('.mv-mobile-settings').textContent").contains("MB"),"Custom cache usage missing");webButton(web,"检查文件可用性");SystemClock.sleep(1000);check(javascript(web,"document.querySelector('.mv-mobile-settings').textContent").contains("已检查"),"Custom library inspection did not finish");
        javascript(web,"Array.from(document.querySelectorAll('.mv-option')).find(x=>x.textContent.startsWith('浅色模式')).click();true");SystemClock.sleep(200);check("true".equals(javascript(web,"document.querySelector('main').dataset.theme==='light' && !!document.querySelector('[role=checkbox][data-mv-component=checkbox]')")),"Custom checkbox missing in light settings");screenshot("shared-settings-controls-light");
        javascript(web,"Array.from(document.querySelectorAll('.mv-option')).find(x=>x.textContent.startsWith('深色模式')).click();true");SystemClock.sleep(200);check("true".equals(javascript(web,"document.querySelector('main').dataset.theme==='dark' && document.querySelector('[role=checkbox]').getBoundingClientRect().height>=44")),"Custom checkbox lost dark touch target");screenshot("shared-settings-controls-dark");webClick(web,"[aria-label=\"关闭弹窗\"]");
        try(android.content.res.AssetFileDescriptor file=context.getContentResolver().openAssetFileDescriptor(tracks.get(0).uri,"r")){check(file!=null,"Collection operations deleted a music file");}
        // Rejection must be atomic: no partial updates when any ID is unknown.
        Set<String> saved=new HashSet<>(prefs.getStringSet("playlist_"+copied,Collections.emptySet()));boolean rejected=false;try{PortableLibraryActions.execute(preview,tracks,"addManyToPlaylist",new org.json.JSONObject().put("playlist",copied).put("ids",new org.json.JSONArray().put(Long.toString(tracks.get(0).id)).put("not-authorized")));}catch(Exception expected){rejected=true;}check(rejected&&saved.equals(prefs.getStringSet("playlist_"+copied,Collections.emptySet())),"Invalid batch partially changed a playlist");
        report.append("PASS phone collection create/rename/delete, batch add/remove, rename anchors, lyric/info details and shared settings\n");
    }
    private void tagEditing()throws Exception{
        Context context=getTargetContext();Uri tree=android.provider.DocumentsContract.buildTreeDocumentUri(TestMusicProvider.AUTHORITY,"root");context.getContentResolver().call(tree,"resetTags",null,null);Set<String> folders=Collections.singleton(tree.toString());List<Song> songs=new ArrayList<>();
        for(String format:new String[]{"mp3","flac"}){Uri uri=android.provider.DocumentsContract.buildDocumentUriUsingTree(tree,"tags."+format);Song song=new Song(format.equals("mp3")?41001:41002,1000,0,"Original "+format,"Artist","Album","tags."+format,uri);songs.add(song);}
        context.getSharedPreferences("library",0).edit().putStringSet("music_folders",folders).putBoolean("scan_recursive",false).commit();context.getSharedPreferences("portable",0).edit().clear().commit();LibrarySnapshot.write(context,"folders\n"+LibrarySnapshot.source(folders,false),songs);
        check(context.getPackageManager().getLaunchIntentForPackage(context.getPackageName()).getComponent().getClassName().endsWith("PortablePlayerActivity"),"Launcher still enters native content");
        PortablePlayerActivity preview=(PortablePlayerActivity)startActivitySync(new Intent(context,PortablePlayerActivity.class).putExtra("minivoice.uiRegression",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK));android.webkit.WebView web=(android.webkit.WebView)field(preview,"web");SystemClock.sleep(1600);
        webClick(web,".mv-song[data-song-id='41001']");SystemClock.sleep(300);javascript(web,"Array.from(document.querySelectorAll('.mv-song')).find(node=>node.dataset.songId==='41001').dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true}));true");SystemClock.sleep(250);webButton(web,"编辑歌曲标签与歌词");SystemClock.sleep(350);
        javascript(web,"(()=>{const input=document.querySelector('input[aria-label=歌曲名称]');Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,'自有组件写入');input.dispatchEvent(new Event('input',{bubbles:true}));return true;})()");SystemClock.sleep(200);webButton(web,"保存到原文件");webButton(web,"确认写入原文件");SystemClock.sleep(1600);
        AudioTags written=AudioTags.read(context,songs.get(0).uri,false);check("自有组件写入".equals(written.title),"Custom editor did not write the real document: "+written.title+" / "+AudioTags.read(context,songs.get(1).uri,false).title+" UI "+javascript(web,"document.querySelector('[role=dialog]')?.textContent"));
        // Disable scan for this isolated rollback test and directly exercise the same adapter.
        for(int i=0;i<50&&LibraryScanService.isRunning();i++)SystemClock.sleep(100);
        byte[] before;try(InputStream in=context.getContentResolver().openInputStream(songs.get(1).uri)){before=in.readAllBytes();}
        context.getContentResolver().call(tree,"failTagWrite",null,null);boolean failed=false;try{PortableMetadataActions.execute(preview,songs,"writeMetadata",new org.json.JSONObject().put("id","41002").put("title","Rollback").put("artist","Artist").put("album","Album").put("lyrics","[00:00.00]Lyrics"));}catch(Exception expected){failed=true;}check(failed,"Partial write did not fail");try(InputStream in=context.getContentResolver().openInputStream(songs.get(1).uri)){check(Arrays.equals(before,in.readAllBytes()),"Partial write did not restore original document");}
        File recovery=new File(context.getFilesDir(),"edit-recovery");recovery.mkdirs();File backup=new File(recovery,"original-42.audio"),journal=new File(recovery,"original-42.audio.json");java.nio.file.Files.write(backup.toPath(),before);java.nio.file.Files.write(journal.toPath(),new org.json.JSONObject().put("uri",songs.get(1).uri.toString()).put("name","恢复测试").put("backup",backup.getName()).toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));try(OutputStream out=context.getContentResolver().openOutputStream(songs.get(1).uri,"rwt")){out.write(new byte[80]);}check(PortableMetadataActions.recoveries(preview).length()==1,"Interrupted write recovery not discoverable");PortableMetadataActions.execute(preview,songs,"restoreMetadata",new org.json.JSONObject().put("id",journal.getName()));try(InputStream in=context.getContentResolver().openInputStream(songs.get(1).uri)){check(Arrays.equals(before,in.readAllBytes()),"Interrupted write recovery failed");}
        check(recovery.listFiles()==null||recovery.listFiles().length==0,"Successful rollback leaked recovery files");main(preview::finish);report.append("PASS default custom launcher, real MP3 editor save, FLAC partial-write and interrupted-write restoration\n");
    }
    private void playbackIconCenters(android.webkit.WebView web){check("true".equals(javascript(web,"Array.from(document.querySelectorAll('.mv-button[data-playback-primary]')).filter(node=>node.getClientRects().length).every(node=>{const svg=node.querySelector('svg'),b=node.getBoundingClientRect(),s=svg.getBoundingClientRect(),playing=node.dataset.playbackState==='playing',shift=playing?0:s.width/parseFloat(getComputedStyle(svg).width);return Math.abs(s.x+s.width/2-b.x-b.width/2-shift)<.3&&Math.abs(s.y+s.height/2-b.y-b.height/2)<.3&&(!playing||(svg.dataset.icon==='pauseFilled'&&svg.getAttribute('stroke-width')==='0'))})")),"Phone playback SVG is off-center or uses thin pause lines");}
    private void webScale(android.webkit.WebView web,int value){
        javascript(web,"(()=>{const s=document.querySelector('.wp-settings [role=slider]');s.focus();for(const key of ['Home',...Array("+(value-60)+").fill('ArrowRight')]){s.dispatchEvent(new KeyboardEvent('keydown',{key,bubbles:true}));s.dispatchEvent(new KeyboardEvent('keyup',{key,bubbles:true}));}})()");SystemClock.sleep(200);
    }
    private void queueDetentDrag(android.webkit.WebView web,int distance,boolean cancel)throws Exception{
        org.json.JSONArray hit=new org.json.JSONArray(javascript(web,"(()=>{const r=document.querySelector('.mv-modal-grip').getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2,innerWidth]})()"));float ratio=web.getWidth()/(float)hit.getDouble(2);int[] origin=new int[2];main(()->web.getLocationOnScreen(origin));float x=origin[0]+(float)hit.getDouble(0)*ratio,y=origin[1]+(float)hit.getDouble(1)*ratio;long now=SystemClock.uptimeMillis();pointer(now,now,MotionEvent.ACTION_DOWN,x,y);for(int i=1;i<=10;i++){SystemClock.sleep(24);pointer(now,SystemClock.uptimeMillis(),MotionEvent.ACTION_MOVE,x,y+distance*ratio*i/10);}pointer(now,SystemClock.uptimeMillis(),cancel?MotionEvent.ACTION_CANCEL:MotionEvent.ACTION_UP,x,y+distance*ratio);SystemClock.sleep(450);
    }
    private void queueDetentContracts(android.webkit.WebView web)throws Exception{
        webClick(web,".wp-dock-controls [aria-label=播放队列]");
        String before=javascript(web,"document.querySelector('.mv-modal').getBoundingClientRect().height");
        queueDetentDrag(web,-180,false);
        check("true".equals(javascript(web,"document.querySelector('.mv-modal').dataset.sheetExpanded==='true'&&document.querySelector('.mv-modal').getBoundingClientRect().height>innerHeight*.85&&document.querySelectorAll('.mv-modal .mv-custom-scroll-rail').length===1")),"Queue upward finger pull did not expand into one list viewport");screenshot("queue-expanded-finger");
        queueDetentDrag(web,50,true);check("true".equals(javascript(web,"document.querySelector('.mv-modal').dataset.sheetExpanded==='true'")),"Cancelled queue pull changed detent");
        queueDetentDrag(web,100,false);check("true".equals(javascript(web,"document.querySelector('.mv-modal').dataset.sheetExpanded==='false'&&Math.abs(document.querySelector('.mv-modal').getBoundingClientRect().height-"+before+")<2")),"Queue downward pull did not return to initial height");webClick(web,"[aria-label=关闭弹窗]");report.append("PASS queue real finger upward expansion, downward detent, cancellation and one scroll owner\n");
    }
    private void systemThemeContracts(android.webkit.WebView web)throws Exception{
        int previous=((android.app.UiModeManager)getTargetContext().getSystemService(Context.UI_MODE_SERVICE)).getNightMode();
        try{
            webClick(web,"[aria-label=打开侧边栏]");webClick(web,".mv-drawer [aria-label=设置]");
            javascript(web,"Array.from(document.querySelectorAll('.mv-mobile-settings button')).find(n=>n.textContent.startsWith('跟随系统')).click();true");
            for(String mode:new String[]{"yes","no"}){
                getUiAutomation().executeShellCommand("cmd uimode night "+mode).close();SystemClock.sleep(2200);
                String theme=mode.equals("yes")?"dark":"light";
                check(javascript(web,"document.querySelector('main').dataset.theme").contains(theme),"Native system theme did not reach WebView: "+theme);
            }
            webClick(web,"[aria-label=关闭弹窗]");
            report.append("PASS Android native system dark/light updates while settings remains mounted\n");
        }finally{getUiAutomation().executeShellCommand("cmd uimode night "+(previous==android.app.UiModeManager.MODE_NIGHT_YES?"yes":previous==android.app.UiModeManager.MODE_NIGHT_NO?"no":"auto")).close();}
    }
    private void mobilePlayerFlow(android.webkit.WebView web,PortablePlayerActivity preview)throws Exception{
        webClick(web,"[aria-label=打开侧边栏]");webStyle(web,"音乐墙");webClick(web,"[aria-label=关闭侧边栏]");
        webClick(web,".wp-dock-content .mv-now");SystemClock.sleep(700);webClick(web,".wp-controls [aria-label=展开播放器]");SystemClock.sleep(500);
        for(int wait=0;wait<40&&!"true".equals(javascript(web,"[...document.querySelectorAll('.mv-wall-focused-art')].some(n=>n.naturalWidth>0&&getComputedStyle(n).visibility==='visible')"));wait++)SystemClock.sleep(100);
        javascript(web,"window.nativeExpandedNode=document.querySelector('.mv-wall-focused');window.nativeSwapFrames=[];window.nativeBaseDecode=HTMLImageElement.prototype.decode;HTMLImageElement.prototype.decode=function(){return this.classList.contains('mv-wall-focused-art')?new Promise(resolve=>setTimeout(()=>window.nativeBaseDecode.call(this).then(resolve),700)):window.nativeBaseDecode.call(this)};window.nativeSwapUntil=performance.now()+1300;requestAnimationFrame(function sample(){const n=document.querySelector('.mv-wall-focused'),r=n?.getBoundingClientRect();window.nativeSwapFrames.push(!!n&&n===window.nativeExpandedNode&&Math.abs(r.x)<1&&Math.abs(r.y)<1&&Math.abs(r.width-innerWidth)<1&&Math.abs(r.height-innerHeight)<1&&Number(n.style.getPropertyValue('--wall-surface-opacity'))===1&&[...n.querySelectorAll('.mv-wall-focused-art')].some(a=>a.naturalWidth>0&&getComputedStyle(a).visibility==='visible'));if(performance.now()<window.nativeSwapUntil)requestAnimationFrame(sample)});true");
        String before=javascript(web,"document.querySelector('.mv-wall-focused').dataset.wallId");webTap(web,".wp-controls [aria-label=下一首]");
        boolean followed=false;for(int i=0;i<40;i++){String after=javascript(web,"document.querySelector('.mv-wall-focused')?.dataset.wallId");if(!after.equals(before)&&"true".equals(javascript(web,"!!document.querySelector('.mv-wall-focused.is-expanded.is-current')"))){followed=true;break;}SystemClock.sleep(100);}check(followed,"Expanded card did not follow actual native next song");SystemClock.sleep(1400);check("true".equals(javascript(web,"window.nativeSwapFrames.length>2&&window.nativeSwapFrames.every(Boolean)")),"Native expanded handoff exposed a small/blank card");javascript(web,"HTMLImageElement.prototype.decode=window.nativeBaseDecode;true");
        webClick(web,"[aria-label=切换到大字歌词]");check("true".equals(javascript(web,"!!document.querySelector('[data-mv-component=kinetic-lyrics]')")),"Native kinetic surface missing");screenshot("android-flow-native-kinetic");
        main(()->preview.setRequestedOrientation(android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE));SystemClock.sleep(1000);
        javascript(web,"for(const [k,v] of Object.entries({left:42,right:26,top:0,bottom:8}))document.documentElement.style.setProperty('--mv-safe-'+k,v+'px');dispatchEvent(new Event('minivoice-insets'));true");SystemClock.sleep(400);
        check("true".equals(javascript(web,"(()=>{const h=document.querySelector('.wp-header').getBoundingClientRect(),f=document.querySelector('.wp-footer').getBoundingClientRect();return h.left>=41.9&&h.right<=innerWidth-25.9&&f.left>=41.9&&f.right<=innerWidth-25.9&&f.bottom<=innerHeight-7.9})()")),"Native expanded content ignores cutout insets");screenshot("android-flow-native-landscape-safe");
        webClick(web,"[aria-label=收起播放器]");SystemClock.sleep(500);check("true".equals(javascript(web,"(()=>{const a=document.querySelector('[data-wall-control=settings]').getBoundingClientRect(),b=document.querySelector('[aria-label=打开侧边栏]').getBoundingClientRect();return Math.abs(a.left-b.left)<1&&a.top>innerHeight/2})()")),"Native landscape settings not aligned");
        webClick(web,"[aria-label=打开侧边栏]");webStyle(web,"音乐库");webClick(web,"[aria-label=关闭侧边栏]");SystemClock.sleep(600);
        check("true".equals(javascript(web,"!document.querySelector('main').classList.contains('is-player')&&getComputedStyle(document.querySelector('.mv-library')).display!=='none'")),"Native library style opened player instead of list");
        screenshot("android-flow-native-library");report.append("PASS native next-song expanded follow, lyric mode, landscape safe content/settings and list style entry; timings "+javascript(web,"document.querySelector('main').dataset.styleTimings")+"\n");
        main(()->preview.setRequestedOrientation(android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT));
    }

    private void mobileSurfaceContracts(android.webkit.WebView web,PortablePlayerActivity preview)throws Exception{
        webClick(web,"[aria-label=打开侧边栏]");
        for(String style:new String[]{"音乐墙","简易","音乐库"}){
            webStyle(web,style);
            for(String theme:new String[]{"light","dark"}){
                webTheme(web,theme);
                check("true".equals(javascript(web,"(()=>{const s=getComputedStyle(document.querySelector('.mv-drawer nav'));return s.backgroundImage==='none'&&s.boxShadow==='none'&&getComputedStyle(document.querySelector('.mv-drawer-shade'),'::before').clipPath==='none'})()")),"Mobile drawer contains stacked/darkened glass");
                screenshot("neutral-native-drawer-"+style+"-"+theme);
                webClick(web,".mv-drawer [aria-label=设置]");
                String expected=theme.equals("light")?"rgb(34, 40, 48)":"rgb(240, 243, 248)";
                check("true".equals(javascript(web,"(()=>{const n=document.querySelector('.mv-modal'),s=getComputedStyle(n);return s.color==='"+expected+"'&&s.backdropFilter.includes('0.72')&&parseFloat(getComputedStyle(n.querySelector('header>button')).width)>=44})()")),"Mobile sheet neutral palette/sample/hit target failed "+javascript(web,"(()=>{const n=document.querySelector('.mv-modal'),s=getComputedStyle(n);return JSON.stringify({theme:document.querySelector('main').dataset.theme,color:s.color,filter:s.backdropFilter,width:n.querySelector('header>button').getBoundingClientRect().width})})()"));
                screenshot("neutral-native-settings-"+style+"-"+theme);webClick(web,"[aria-label=关闭弹窗]");
                if(style.equals("音乐墙")){
                    webClick(web,"[aria-label=音乐墙设置]");
                    check("true".equals(javascript(web,"(()=>{const n=document.querySelector('.wp-scale-controls .mv-slider');return parseFloat(getComputedStyle(n).height)>=44&&n.querySelectorAll('.mv-slider-mark').length===7&&getComputedStyle(n.querySelector('.mv-slider-mark>i')).boxShadow==='none'&&getComputedStyle(n.querySelector('.mv-slider-knob')).width==='18px'})()")),"Mobile scale clarity or hit region failed");
                    webTap(web,".wp-scale-controls [data-slider-mark='90']");
                    check("true".equals(javascript(web,"document.querySelector('.wp-scale-controls .mv-slider').getAttribute('aria-valuenow')==='90'")),"Trusted mark tap did not select 90 percent");
                    screenshot("neutral-native-scale-"+theme);webClick(web,"[aria-label=关闭弹窗]");
                }
                webClick(web,"[aria-label=打开侧边栏]");
            }
        }
        report.append("PASS Android WebView neutral panels in three styles/light/dark, real backdrop, seven crisp marks, trusted 90 percent tap and 44px controls\n");
    }

    private void scanProgressUi()throws Exception{
        Context context=getTargetContext();Uri tree=android.provider.DocumentsContract.buildTreeDocumentUri(TestMusicProvider.AUTHORITY,"root");
        context.getContentResolver().call(tree,"reset",null,null);
        Set<String> folders=Collections.singleton(tree.toString());List<Song> tracks=FolderLibrary.scan(context,folders,false,(a,b,c)->{},Collections.emptyList());
        context.getSharedPreferences("library",0).edit().putStringSet("music_folders",folders).putBoolean("scan_recursive",false).commit();
        context.getSharedPreferences("portable",0).edit().clear().commit();LibrarySnapshot.write(context,"folders\n"+LibrarySnapshot.source(folders,false),tracks);
        PortablePlayerActivity preview=(PortablePlayerActivity)startActivitySync(new Intent(context,PortablePlayerActivity.class).putExtra("minivoice.uiRegression",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK));
        android.webkit.WebView web=(android.webkit.WebView)field(preview,"web");
        for(int i=0;i<80&&!"true".equals(javascript(web,"!!document.querySelector('[aria-label=打开侧边栏]')"));i++)SystemClock.sleep(150);
        context.getContentResolver().call(tree,"slow",null,null);
        try{
            main(()->LibraryScanService.request(context,true,false,false));
            boolean shown=false;for(int i=0;i<60;i++){if("true".equals(javascript(web,"!!document.querySelector('.mv-scan-status')"))){shown=true;break;}SystemClock.sleep(100);}
            check(shown,"Existing library rescan has no persistent status");
            android.app.NotificationManager manager=(android.app.NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
            android.service.notification.StatusBarNotification notice=null;
            for(android.service.notification.StatusBarNotification item:manager.getActiveNotifications())if(item.getId()==2)notice=item;
            check(notice!=null&&notice.isOngoing(),"Scan ongoing progress notification missing");
            context.startActivity(new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));SystemClock.sleep(1000);
            check(LibraryScanService.isRunning(),"Scan did not survive backgrounding");
            notice.getNotification().contentIntent.send();SystemClock.sleep(1200);
            check("true".equals(javascript(web,"document.querySelector('.mv-modal')?.textContent.includes('音乐库')||false")),"Scan notification did not open details");
            for(int i=0;i<180&&LibraryScanService.isRunning();i++)SystemClock.sleep(250);
            check(!LibraryScanService.isRunning(),"Background scan did not finish");SystemClock.sleep(1000);
            check("false".equals(javascript(web,"!!document.querySelector('.mv-scan-status')")),"Completed scan status did not clear");
            report.append("PASS actual service progress, persistent existing-library indicator, ongoing notification, background continuation and notification detail navigation\n");
        }finally{context.getContentResolver().call(tree,"fast",null,null);main(preview::finish);}
    }

    private void portableKeyboard()throws Exception{
        Context context=getTargetContext();
        context.getSharedPreferences("portable",0).edit().putString("workspace","{\"version\":1,\"section\":\"音乐库\",\"pages\":{\"appearance\":{\"style\":\"wall\",\"theme\":\"light\"}}}").commit();
        PortablePlayerActivity preview=(PortablePlayerActivity)startActivitySync(new Intent(context,PortablePlayerActivity.class).putExtra("minivoice.uiRegression",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK));
        android.webkit.WebView web=(android.webkit.WebView)field(preview,"web");SystemClock.sleep(1800);
        webTap(web,"[aria-label=打开侧边栏]");webButton(web,"新建歌单");SystemClock.sleep(400);
        webTap(web,"input[aria-label=歌单名称]");SystemClock.sleep(1000);
        main(()->check(web.getRootWindowInsets().isVisible(android.view.WindowInsets.Type.ime()),"Actual Android keyboard did not open"));
        check("true".equals(javascript(web,"(()=>{const button=document.querySelector('.mv-confirm'),r=button.getBoundingClientRect(),v=visualViewport,modal=document.querySelector('.mv-modal').getBoundingClientRect();const bottom=Math.min(v.offsetTop+v.height,innerHeight-(parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--mv-keyboard-bottom'))||0));return r.top>=v.offsetTop&&r.bottom<=bottom&&modal.top>=v.offsetTop&&modal.bottom<=bottom&&parseFloat(getComputedStyle(document.querySelector('input[aria-label=歌单名称]')).fontSize)>=16})()")),"Android keyboard overlaps modal or subtracts keyboard height twice");
        report.append("KEYBOARD_GEOMETRY "+javascript(web,"JSON.stringify({innerHeight,viewport:{height:visualViewport.height,top:visualViewport.offsetTop},layer:document.querySelector('.mv-modal-shade').getBoundingClientRect(),modal:document.querySelector('.mv-modal').getBoundingClientRect(),button:document.querySelector('[aria-label=关闭弹窗]').getBoundingClientRect()})")+"\n");
        main(()->report.append("NATIVE_KEYBOARD webHeight="+web.getHeight()+" decor="+preview.getWindow().getDecorView().getHeight()+" ime="+web.getRootWindowInsets().getInsets(android.view.WindowInsets.Type.ime()).bottom+"\n"));
        screenshot("shared-keyboard-playlist");webTap(web,"[aria-label=关闭弹窗]");SystemClock.sleep(500);
        check("true".equals(javascript(web,"!document.querySelector('[role=dialog]')")),"Keyboard modal did not dismiss");
        report.append("PASS actual Android experience keyboard, visible create button, unchanged viewport subtraction and dismissal\n");main(preview::finish);
    }
    private void portablePlayer()throws Exception{
        Context context=getTargetContext();Uri tree=android.provider.DocumentsContract.buildTreeDocumentUri(TestMusicProvider.AUTHORITY,"root");context.getContentResolver().call(tree,"reset",null,null);
        Set<String> folders=Collections.singleton(tree.toString());List<Song> tracks=FolderLibrary.scan(context,folders,false,(a,b,c)->{},Collections.emptyList());
        // The large list exercises virtual scrolling; only the actual WAV rows are played.
        Song original=tracks.get(0);Song first=new Song(original.id,original.duration,original.albumId,"000 Test",original.artist,original.album,original.path,original.uri);tracks.set(0,first);for(int i=0;i<160;i++)tracks.add(new Song(-30000-i,180000,0,"Portable "+i,"Artist "+i,"Album "+i,first.path,first.uri));
        File originalImage=new File(context.getFilesDir(),"ui-original-artwork.png");android.graphics.Bitmap sourceImage=android.graphics.Bitmap.createBitmap(2048,1536,android.graphics.Bitmap.Config.ARGB_8888);android.graphics.Canvas originalCanvas=new android.graphics.Canvas(sourceImage);android.graphics.Paint sourcePaint=new android.graphics.Paint();sourcePaint.setShader(new android.graphics.LinearGradient(0,0,2048,1536,0xff214573,0xffbed9cd,android.graphics.Shader.TileMode.CLAMP));originalCanvas.drawRect(0,0,2048,1536,sourcePaint);try(FileOutputStream stream=new FileOutputStream(originalImage)){sourceImage.compress(android.graphics.Bitmap.CompressFormat.PNG,100,stream);}sourceImage.recycle();for(Song song:tracks)song.artworkUri=Uri.fromFile(originalImage);
        check(Arrays.equals(java.nio.file.Files.readAllBytes(originalImage.toPath()),Artwork.original(context,first)),"Original artwork bytes were recompressed");
        java.lang.reflect.Method artworkKey=ArtworkCache.class.getDeclaredMethod("key",Song.class);artworkKey.setAccessible(true);for(Song song:tracks){song.artworkVersion="ui-fixture";String cacheKey=(String)artworkKey.invoke(null,song);java.io.File folder=LibraryCache.directory(context,"covers");folder.mkdirs();java.io.File cover=new java.io.File(folder,cacheKey+".jpg");android.graphics.Bitmap bitmap=android.graphics.Bitmap.createBitmap(512,512,android.graphics.Bitmap.Config.ARGB_8888);android.graphics.Canvas canvas=new android.graphics.Canvas(bitmap);android.graphics.Paint paint=new android.graphics.Paint();paint.setShader(new android.graphics.LinearGradient(0,0,512,512,0xff485e96,0xffb3d0c2,android.graphics.Shader.TileMode.CLAMP));canvas.drawRect(0,0,512,512,paint);paint.setShader(null);paint.setColor(0xfff4fff9);paint.setTextSize(70);paint.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);canvas.drawText("MiniVoice",60,265,paint);try(java.io.FileOutputStream out=new java.io.FileOutputStream(cover)){bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG,90,out);}bitmap.recycle();java.nio.file.Files.write(new java.io.File(folder,cacheKey+".stamp").toPath(),(song.artworkUri+"\n"+song.artworkVersion+"\nquality-v2").getBytes(java.nio.charset.StandardCharsets.UTF_8));new java.io.File(folder,cacheKey+".none").delete();song.artworkPrepared=true;song.artworkCacheKey=cacheKey;song.artworkFile=cover;}
        first.lyricsRaw="[00:00.000]原文\n[00:00.000]Translation\n[00:01.000]第二行";first.lyricsPrepared=true;
        context.getSharedPreferences("library",0).edit().putStringSet("music_folders",folders).putBoolean("scan_recursive",false).commit();
        // This flow starts in library style regardless of the product default or earlier tests.
        context.getSharedPreferences("portable",0).edit().clear().putString("workspace","{\"version\":1,\"pages\":{\"appearance\":{\"style\":\"library\",\"theme\":\"dark\"}}}").commit();LibrarySnapshot.write(context,"folders\n"+LibrarySnapshot.source(folders,false),tracks);
        PortablePlayerActivity preview=(PortablePlayerActivity)startActivitySync(new Intent(context,PortablePlayerActivity.class).putExtra("minivoice.uiRegression",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK));
        android.webkit.WebView web=(android.webkit.WebView)field(preview,"web");boolean ready=false;for(int i=0;i<80;i++){if("162".equals(javascript(web,"document.querySelector('.mv-song-list>div')?.style.height==='11664px'?162:0"))){ready=true;break;}SystemClock.sleep(150);}check(ready,"Shared player did not load authorized library");
        check("true".equals(javascript(web,"document.querySelector('.mv-song').click();true")),"Shared song click failed");SystemClock.sleep(700);
        if("playerFlow".equals(arguments.getString("mode"))){mobilePlayerFlow(web,preview);main(preview::finish);return;}
        if("surfaces".equals(arguments.getString("mode"))){mobileSurfaceContracts(web,preview);main(preview::finish);return;}
        if("wall".equals(arguments.getString("mode"))){webClick(web,"[aria-label=打开侧边栏]");webStyle(web,"音乐墙");webClick(web,"[aria-label=关闭侧边栏]");SystemClock.sleep(700);wallVersionContracts(web,preview,first);main(preview::finish);return;}
        long beforeHaptic=(Long)field(preview,"lastHaptic");
        org.json.JSONArray hit=new org.json.JSONArray(javascript(web,"(()=>{const r=document.querySelector('[aria-label=打开侧边栏]').getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2,innerWidth]})()"));float hapticRatio=web.getWidth()/(float)hit.getDouble(2);
        tap(web,(float)hit.getDouble(0)*hapticRatio,(float)hit.getDouble(1)*hapticRatio);SystemClock.sleep(350);
        check((Long)field(preview,"lastHaptic")>beforeHaptic,"Trusted button tap did not invoke Android haptic bridge");
        long afterHaptic=(Long)field(preview,"lastHaptic");
        javascript(web,"document.querySelector('[aria-label=关闭侧边栏]').disabled=true;true");
        hit=new org.json.JSONArray(javascript(web,"(()=>{const r=document.querySelector('[aria-label=关闭侧边栏]').getBoundingClientRect();return [r.x+r.width/2,r.y+r.height/2]})()"));
        tap(web,(float)hit.getDouble(0)*hapticRatio,(float)hit.getDouble(1)*hapticRatio);SystemClock.sleep(200);
        check((Long)field(preview,"lastHaptic")==afterHaptic,"Disabled button emitted haptic feedback");
        javascript(web,"document.querySelector('[aria-label=关闭侧边栏]').disabled=false;true");webClick(web,"[aria-label=关闭侧边栏]");
        report.append("PASS trusted tap Android system haptic invocation and disabled suppression (physical vibration not measured)\n");

        check("true".equals(javascript(web,"document.querySelector('.mv-song img')?.naturalWidth>0")),"Shared authorized cover endpoint did not decode artwork");
        final PortablePlayerActivity initialPreview=preview;main(()->{PlaybackService service=(PlaybackService)field(initialPreview,"playback");check(service!=null&&service.current()!=null&&service.current().id==first.id,"Shared play did not reach real service");});
        javascript(web,"document.querySelector('.mv-now').click();true");SystemClock.sleep(200);
        check(javascript(web,"document.querySelector('.mv-lyric-lines').textContent").contains("Translation"),"Shared bilingual lyrics missing");
        javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(200);
        for(String style:new String[]{"简易","音乐库","音乐墙"}){webStyle(web,style);playbackIconCenters(web);check("true".equals(javascript(web,"document.querySelector('main').dataset.style==='wall'?getComputedStyle(document.querySelector('.mv-drawer')).backdropFilter.includes('blur'):document.querySelector('.mv-drawer-material')?.dataset.sampled==='true'&&[...document.querySelectorAll('.mv-drawer-sample img')].some(image=>image.naturalWidth>0)")),"Style glass source in "+style+": "+javascript(web,"JSON.stringify({style:document.querySelector('main').dataset.style,filter:getComputedStyle(document.querySelector('.mv-drawer')).backdropFilter,sampled:document.querySelector('.mv-drawer-material')?.dataset.sampled,images:[...document.querySelectorAll('.mv-drawer-sample img')].map(i=>i.naturalWidth)})"));check("true".equals(javascript(web,"!!document.querySelector('.mv-drawer')")),"Shared style switch closed drawer");check("true".equals(javascript(web,"(()=>{const scene=document.querySelector('.mv-scene'),s=getComputedStyle(scene),m=new DOMMatrixReadOnly(s.transform);if(document.querySelector('main').dataset.style==='wall'){const p=document.querySelector('.mv-wall-plane');return scene.inert&&m.isIdentity&&scene.offsetWidth===innerWidth&&scene.offsetHeight===innerHeight&&JSON.parse(p.dataset.displayCamera).scale<JSON.parse(p.dataset.camera).scale;}return scene.inert&&m.a<.98&&m.a>.94&&s.borderRadius==='24px'})()")),"Drawer background depth missing in "+style);if(!style.equals("音乐墙"))systemBarContracts(preview,web);}
        report.append("PASS library/simple actual system-bar insets in portrait and landscape\n");
        javascript(web,"document.querySelector('[aria-label=关闭侧边栏]').click();true");SystemClock.sleep(400);
        javascript(web,"window.drawerFrames=[];window.drawerUntil=performance.now()+500;document.querySelector('[aria-label=打开侧边栏]').click();requestAnimationFrame(function sample(){const d=document.querySelector('.mv-drawer');if(d)window.drawerFrames.push(new DOMMatrixReadOnly(getComputedStyle(d).transform).m41);if(performance.now()<window.drawerUntil)requestAnimationFrame(sample)});true");SystemClock.sleep(550);
        check("true".equals(javascript(web,"(()=>{const d=document.querySelector('.mv-drawer');return d.offsetWidth<=Math.min(innerWidth*.8,340)+1&&window.drawerFrames.some(x=>x < -80)&&window.drawerFrames.some(x=>x > -80&&x < -1)&&Math.abs(new DOMMatrixReadOnly(getComputedStyle(d).transform).m41)<1})()")),"Drawer width or actual sliding frames failed");
        javascript(web,"window.drawerExitSamples=[];window.exitUntil=performance.now()+600;document.querySelector('[aria-label=关闭侧边栏]').click();requestAnimationFrame(function sample(){const g=document.querySelector('[data-surface-exit=drawer][inert] .mv-drawer');if(g)window.drawerExitSamples.push(new DOMMatrixReadOnly(getComputedStyle(g).transform).m41);if(performance.now()<window.exitUntil)requestAnimationFrame(sample)});true");SystemClock.sleep(700);
        check("true".equals(javascript(web,"window.drawerExitSamples.length>=2&&new Set(window.drawerExitSamples).size>=2")),"Drawer exit had no visible slide frames");
        check("true".equals(javascript(web,"!document.querySelector('[data-surface-exit=drawer]')")),"Drawer exit did not clean up");check("true".equals(javascript(web,"(()=>{const scene=document.querySelector('.mv-scene');return !scene.classList.contains('is-drawer-behind')&&!scene.inert&&new DOMMatrixReadOnly(getComputedStyle(scene).transform).isIdentity})()")),"Drawer background did not restore");webClick(web,"[aria-label=打开侧边栏]");SystemClock.sleep(400);
        check("true".equals(javascript(web,"(()=>{const scene=document.querySelector('.mv-scene'),panels=[...scene.querySelectorAll('.mv-glass,.mv-library,.mv-lyrics,.mv-wall-dock')];return panels.every(p=>getComputedStyle(p).borderTopColor!=='rgba(0, 0, 0, 0)'&&getComputedStyle(p).boxShadow!=='none')&&getComputedStyle(document.querySelector('.mv-drawer nav')).boxShadow!=='none'})()")),"Drawer removed background outlines or lost section depth");
        if("wall".equals(javascript(web,"document.querySelector('main').dataset.style").replace("\"","")))check("true".equals(javascript(web,"(()=>{const scene=document.querySelector('.mv-scene'),r=scene.getBoundingClientRect();return !document.querySelector('.mv-drawer-wall-backdrop')&&Math.abs(r.width-innerWidth)<1&&Math.abs(r.height-innerHeight)<1&&Math.abs(r.left)<1&&Math.abs(r.top)<1&&[...scene.querySelectorAll('.mv-wall-card img')].some(i=>i.naturalWidth>0)})()")),"Wall drawer must scale the live canvas without a stitched backdrop");
        report.append("PASS narrow drawer actual slide frames, three-style background depth/restore, retained exit and Mac fragment style sweep with real app raster\n");

        webStyle(web,"音乐库");webTheme(web,"dark");javascript(web,"document.querySelector('[aria-label=\"关闭侧边栏\"]').click();true");SystemClock.sleep(200);check(javascript(web,"document.querySelector('main').dataset.theme").contains("dark"),"Shared theme not restored");
        javascript(web,"document.querySelector('.mv-back').click();true");SystemClock.sleep(300);
        javascript(web,"document.querySelector('.mv-song-list').scrollTop=413;true");SystemClock.sleep(700);String before=javascript(web,"document.querySelector('.mv-song-list').scrollTop");check(near(before,"413"),"Shared fixture did not scroll: "+before+" "+javascript(web,"JSON.stringify({body:document.querySelector('.mv-body').className,style:document.querySelector('main').dataset.style,height:document.querySelector('.mv-song-list').clientHeight,scroll:document.querySelector('.mv-song-list').scrollHeight,error:document.querySelector('.mv-error')?.textContent})"));SystemClock.sleep(1000);check(near(before,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Polling reset shared scroll");
        javascript(web,"document.querySelector('.mv-now').click();true");SystemClock.sleep(200);javascript(web,"document.querySelector('.mv-back').click();true");SystemClock.sleep(250);check(near(before,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Hidden playback page overwrote list anchor");
        javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(150);javascript(web,"Array.from(document.querySelectorAll('.mv-drawer nav button')).find(x=>x.textContent==='歌手').click();true");SystemClock.sleep(450);
        webListReady(web);
        javascript(web,"document.querySelector('.mv-song-list').scrollTop=767;true");SystemClock.sleep(400);String parentAnchor=javascript(web,"document.querySelector('.mv-song-list').scrollTop");check(near(parentAnchor,"767"),"Shared artist fixture did not scroll: "+parentAnchor+" "+javascript(web,"JSON.stringify({heading:document.querySelector('.mv-section-title')?.textContent,lists:[...document.querySelectorAll('.mv-song-list')].map(n=>({h:n.clientHeight,s:n.scrollHeight,top:n.scrollTop})),error:document.querySelector('.mv-error')?.textContent})"));
        for(int cycle=0;cycle<3;cycle++){javascript(web,"Array.from(document.querySelectorAll('.mv-song')).find(x=>x.offsetTop>=document.querySelector('.mv-song-list').scrollTop).click();true");SystemClock.sleep(350);check("true".equals(javascript(web,"!!document.querySelector('.mv-back')")),"Shared artist group failed to open");javascript(web,"document.querySelector('.mv-back').click();true");SystemClock.sleep(350);webListReady(web);check(near(parentAnchor,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Shared artist return lost anchor: "+parentAnchor+" -> "+javascript(web,"document.querySelector('.mv-song-list').scrollTop"));}
        javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(150);javascript(web,"Array.from(document.querySelectorAll('.mv-drawer nav button')).find(x=>x.textContent==='音乐库').click();true");SystemClock.sleep(350);webListReady(web);check(near(before,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Shared library return lost anchor: "+before+" -> "+javascript(web,"document.querySelector('.mv-song-list').scrollTop"));
        javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(900);screenshot("shared-player-drawer-dark");javascript(web,"document.querySelector('[aria-label=\"关闭侧边栏\"]').click();true");
        main(preview::finish);SystemClock.sleep(300);preview=(PortablePlayerActivity)startActivitySync(new Intent(context,PortablePlayerActivity.class).putExtra("minivoice.uiRegression",true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));web=(android.webkit.WebView)field(preview,"web");SystemClock.sleep(1800);
        check(javascript(web,"document.querySelector('main')?.dataset.theme").contains("dark"),"Shared relaunch lost theme");check(near(before,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Shared relaunch lost anchor");
        String favoriteId=javascript(web,"document.querySelector('.mv-song').dataset.songId").replace("\"","");boolean wasFavorite=context.getSharedPreferences("library",0).getStringSet("favorites",Collections.emptySet()).contains(favoriteId);javascript(web,"document.querySelector('.mv-song .mv-favorite').click();true");SystemClock.sleep(500);check(context.getSharedPreferences("library",0).getStringSet("favorites",Collections.emptySet()).contains(favoriteId)!=wasFavorite,"Shared favorite did not reach platform store");
        javascript(web,"document.querySelector('[aria-label=\"播放队列\"]').click();true");SystemClock.sleep(250);check(javascript(web,"document.querySelector('[role=dialog]').getAttribute('aria-label')").contains("播放队列"),"Shared queue did not open");javascript(web,"document.querySelector('[aria-label=\"关闭弹窗\"]').click();true");
        javascript(web,"document.querySelector('[aria-label=\"播放模式\"]').click();true");SystemClock.sleep(150);javascript(web,"Array.from(document.querySelectorAll('.mv-modal .mv-option')).find(x=>x.textContent.includes('单曲循环')).click();true");SystemClock.sleep(200);
        sliderContracts(web,preview);
        customScrollContracts(web);
        componentContracts(web);sheetDragContracts(web);
        menuContracts(web);
        mobileCollections(web,context,tracks,preview);
        final PortablePlayerActivity checkedPreview=preview;main(()->check(((PlaybackService)field(checkedPreview,"playback")).mode==3,"Shared playback mode mapping incorrect"));
        javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(150);javascript(web,"Array.from(document.querySelectorAll('.mv-drawer nav button')).find(x=>x.textContent==='新建歌单').click();true");SystemClock.sleep(150);check(javascript(web,"document.querySelector('[role=dialog]').getAttribute('aria-label')").contains("新建歌单"),"Shared playlist editor did not open");javascript(web,"document.querySelector('[aria-label=\"关闭弹窗\"]').click();true");
        main(()->{PlaybackService service=(PlaybackService)field(checkedPreview,"playback");service.setMode(3);service.setQueue(tracks,0);});SystemClock.sleep(500);
        for(String style:new String[]{"简易","音乐库","音乐墙"})for(String theme:new String[]{"light","dark"}){
            javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(100);webStyle(web,style);webTheme(web,theme);SystemClock.sleep(900);check(javascript(web,"document.querySelector('main').dataset.theme").contains(theme),"Drawer theme switch did not apply");screenshot("shared-parity-drawer-"+style+"-"+theme);javascript(web,"document.querySelector('[aria-label=\"关闭侧边栏\"]').click();true");SystemClock.sleep(150);screenshot("shared-parity-page-"+style+"-"+theme);
        }
        check(near("0",javascript(web,"document.scrollingElement.scrollTop")),"Modal focus scrolled the fixed player shell");
        wallVersionContracts(web,preview,first);
        queueDetentContracts(web);
        systemThemeContracts(web);
        final PortablePlayerActivity last=preview;main(()->{PlaybackService service=(PlaybackService)field(last,"playback");if(service!=null&&service.isPlaying())service.toggle();last.finish();});
        report.append("PASS shared WebView load, real WAV playback, bilingual lyrics, three styles, theme, polling and relaunch anchors\n");
    }
    private void tap(View view){tap(view,view.getWidth()/2f,view.getHeight()/2f);}
    private void tap(View view,float x,float y){int[] location=new int[2];main(()->view.getLocationOnScreen(location));long now=SystemClock.uptimeMillis();pointer(now,now,MotionEvent.ACTION_DOWN,x+location[0],y+location[1]);SystemClock.sleep(70);pointer(now,SystemClock.uptimeMillis(),MotionEvent.ACTION_UP,x+location[0],y+location[1]);}
    private void swipe(View view,float sx,float sy,float ex,float ey){int[] location=new int[2];main(()->view.getLocationOnScreen(location));float x=location[0]+view.getWidth()*sx,y=location[1]+view.getHeight()*sy,dx=view.getWidth()*(ex-sx),dy=view.getHeight()*(ey-sy);long now=SystemClock.uptimeMillis();pointer(now,now,0,x,y);for(int i=1;i<=15;i++){SystemClock.sleep(20);pointer(now,SystemClock.uptimeMillis(),2,x+dx*i/15,y+dy*i/15);}SystemClock.sleep(80);pointer(now,SystemClock.uptimeMillis(),1,x+dx,y+dy);}
    private void pointer(long down,long event,int action,float x,float y){MotionEvent.PointerProperties properties=new MotionEvent.PointerProperties();properties.id=0;properties.toolType=MotionEvent.TOOL_TYPE_FINGER;MotionEvent.PointerCoords coords=new MotionEvent.PointerCoords();coords.x=x;coords.y=y;coords.pressure=action==MotionEvent.ACTION_UP?0:1;coords.size=.1f;MotionEvent motion=MotionEvent.obtain(down,event,action,1,new MotionEvent.PointerProperties[]{properties},new MotionEvent.PointerCoords[]{coords},0,0,1,1,0,0,InputDevice.SOURCE_TOUCHSCREEN,0);sendPointerSync(motion);motion.recycle();}
    private static boolean near(String first,String second){try{return Math.abs(Double.parseDouble(first)-Double.parseDouble(second))<=1;}catch(Exception ignored){return false;}}
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
}
