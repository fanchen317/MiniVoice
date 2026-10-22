package com.xcosmos.minivoice;

import android.app.*;
import android.content.*;
import android.graphics.RectF;
import android.net.Uri;
import android.os.*;
import android.view.*;
import android.widget.*;
import java.lang.reflect.*;
import java.util.*;

/** Runs real Android layouts and input on a dedicated emulator, without a third-party runner. */
public final class UiRegressionInstrumentation extends Instrumentation {
    private MainActivity activity;
    private Bundle arguments;
    private final StringBuilder report=new StringBuilder();
    @Override public void onCreate(Bundle args){super.onCreate(args);arguments=args;start();}
    @Override public void onStart(){Bundle result=new Bundle();try{
        if("crash".equals(arguments.getString("mode"))){new Thread(()->{throw new IllegalStateException("UI_CRASH_PROBE");},"diagnostic-crash-probe").start();SystemClock.sleep(10000);throw new AssertionError("Crash handler did not terminate process");}
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
    private void webName(android.webkit.WebView web,String name){check("true".equals(javascript(web,"(()=>{const input=document.querySelector('input[aria-label=\"歌单名称\"]');if(!input)return false;Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,"+org.json.JSONObject.quote(name)+");input.dispatchEvent(new Event('input',{bubbles:true}));return true;})()")),"Playlist input missing");SystemClock.sleep(150);javascript(web,"document.querySelector('[role=dialog] form').requestSubmit();true");SystemClock.sleep(500);}
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
        javascript(web,"document.querySelector('.mv-song-list').scrollTop=320;true");SystemClock.sleep(400);String before=javascript(web,"document.querySelector('.mv-song-list').scrollTop");webClick(web,"[aria-label=\"歌单操作\"]");webButton(web,"重命名歌单");webName(web,renamed);
        check(prefs.getStringSet("playlists",Collections.emptySet()).contains(renamed)&&!prefs.getStringSet("playlists",Collections.emptySet()).contains(name),"Shared rename did not migrate name");check(prefs.getStringSet("playlist_"+renamed,Collections.emptySet()).size()==30,"Shared rename lost tracks");check(near(before,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Shared playlist rename lost anchor");
        webClick(web,"[aria-label=\"选择歌曲\"]");javascript(web,"document.querySelectorAll('.mv-song')[0].click();document.querySelectorAll('.mv-song')[1].click();true");SystemClock.sleep(180);check(javascript(web,"document.querySelector('.mv-selection-bar').textContent").contains("2 首"),"Shared multi-select failed");
        webButton(web,"批量操作");webButton(web,"加入歌单");webButton(web,"＋ 新建歌单");webName(web,copied);check(prefs.getStringSet("playlist_"+copied,Collections.emptySet()).size()==2,"Shared batch playlist creation lost selection");
        webButton(web,"批量操作");webButton(web,"从此歌单移除");webButton(web,"移除");check(prefs.getStringSet("playlist_"+renamed,Collections.emptySet()).size()==28,"Shared batch remove failed");webButton(web,"完成");
        webClick(web,"[aria-label=\"歌单操作\"]");webButton(web,"删除歌单");webButton(web,"删除");check(!prefs.getStringSet("playlists",Collections.emptySet()).contains(renamed)&&prefs.getStringSet("playlists",Collections.emptySet()).contains(copied),"Shared deletion affected wrong playlist");
        // Read-only information/lyrics actions use the authorized library, not a filesystem path supplied by JS.
        webClick(web,"button[aria-label=\"搜索音乐\"]");javascript(web,"(()=>{const input=document.querySelector('input[aria-label=\"搜索音乐\"]');Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,'000 Test');input.dispatchEvent(new Event('input',{bubbles:true}));return true;})()");SystemClock.sleep(500);javascript(web,"document.querySelector('.mv-song').dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true}));true");SystemClock.sleep(180);webButton(web,"歌曲信息");screenshot("shared-song-info");check(javascript(web,"document.querySelector('.mv-song-info').textContent").contains("000 Test"),"Shared song information missing: "+javascript(web,"document.querySelector('.mv-song-info')?.textContent")+" "+javascript(web,"document.querySelector('.mv-section-title')?.textContent"));webClick(web,"[aria-label=\"关闭弹窗\"]");
        javascript(web,"document.querySelector('.mv-song').dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true}));true");SystemClock.sleep(180);webButton(web,"查看歌词");SystemClock.sleep(600);check(javascript(web,"document.querySelector('.mv-raw-lyrics').textContent").contains("Translation"),"Shared lyric detail lost translation");webClick(web,"[aria-label=\"关闭弹窗\"]");
        javascript(web,"(()=>{const input=document.querySelector('input[aria-label=\"搜索音乐\"]');Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,'');input.dispatchEvent(new Event('input',{bubbles:true}));return true;})()");SystemClock.sleep(350);webClick(web,"button[aria-label=\"收起搜索\"]");
        webClick(web,"[aria-label=\"打开侧边栏\"]");webClick(web,"[aria-label=\"设置\"]");SystemClock.sleep(400);check("true".equals(javascript(web,"!!document.querySelector('[aria-label=\"包含子文件夹\"]')")),"Shared folder settings did not load");check(javascript(web,"document.querySelector('.mv-mobile-settings').textContent").contains("导出诊断报告"),"Shared diagnostic export entry missing");screenshot("shared-phone-settings");webClick(web,"[aria-label=\"关闭弹窗\"]");
        try(android.content.res.AssetFileDescriptor file=context.getContentResolver().openAssetFileDescriptor(tracks.get(0).uri,"r")){check(file!=null,"Collection operations deleted a music file");}
        // Rejection must be atomic: no partial updates when any ID is unknown.
        Set<String> saved=new HashSet<>(prefs.getStringSet("playlist_"+copied,Collections.emptySet()));boolean rejected=false;try{PortableLibraryActions.execute(preview,tracks,"addManyToPlaylist",new org.json.JSONObject().put("playlist",copied).put("ids",new org.json.JSONArray().put(Long.toString(tracks.get(0).id)).put("not-authorized")));}catch(Exception expected){rejected=true;}check(rejected&&saved.equals(prefs.getStringSet("playlist_"+copied,Collections.emptySet())),"Invalid batch partially changed a playlist");
        report.append("PASS phone collection create/rename/delete, batch add/remove, rename anchors, lyric/info details and shared settings\n");
    }
    private void portablePlayer()throws Exception{
        Context context=getTargetContext();Uri tree=android.provider.DocumentsContract.buildTreeDocumentUri(TestMusicProvider.AUTHORITY,"root");context.getContentResolver().call(tree,"reset",null,null);
        Set<String> folders=Collections.singleton(tree.toString());List<Song> tracks=FolderLibrary.scan(context,folders,false,(a,b,c)->{},Collections.emptyList());
        // The large list exercises virtual scrolling; only the actual WAV rows are played.
        Song original=tracks.get(0);Song first=new Song(original.id,original.duration,original.albumId,"000 Test",original.artist,original.album,original.path,original.uri);tracks.set(0,first);for(int i=0;i<160;i++)tracks.add(new Song(-30000-i,180000,0,"Portable "+i,"Artist "+i,"Album "+i,first.path,first.uri));
        java.lang.reflect.Method artworkKey=ArtworkCache.class.getDeclaredMethod("key",Song.class);artworkKey.setAccessible(true);for(Song song:tracks){song.artworkVersion="ui-fixture";String cacheKey=(String)artworkKey.invoke(null,song);java.io.File folder=LibraryCache.directory(context,"covers");folder.mkdirs();java.io.File cover=new java.io.File(folder,cacheKey+".jpg");android.graphics.Bitmap bitmap=android.graphics.Bitmap.createBitmap(512,512,android.graphics.Bitmap.Config.ARGB_8888);android.graphics.Canvas canvas=new android.graphics.Canvas(bitmap);android.graphics.Paint paint=new android.graphics.Paint();paint.setShader(new android.graphics.LinearGradient(0,0,512,512,0xff485e96,0xffb3d0c2,android.graphics.Shader.TileMode.CLAMP));canvas.drawRect(0,0,512,512,paint);paint.setShader(null);paint.setColor(0xfff4fff9);paint.setTextSize(70);paint.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);canvas.drawText("MiniVoice",60,265,paint);try(java.io.FileOutputStream out=new java.io.FileOutputStream(cover)){bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG,90,out);}bitmap.recycle();java.nio.file.Files.write(new java.io.File(folder,cacheKey+".stamp").toPath(),(song.artworkUri+"\n"+song.artworkVersion+"\nquality-v2").getBytes(java.nio.charset.StandardCharsets.UTF_8));new java.io.File(folder,cacheKey+".none").delete();song.artworkPrepared=true;song.artworkCacheKey=cacheKey;song.artworkFile=cover;}
        first.lyricsRaw="[00:00.000]原文\n[00:00.000]Translation\n[00:01.000]第二行";first.lyricsPrepared=true;
        context.getSharedPreferences("library",0).edit().putStringSet("music_folders",folders).putBoolean("scan_recursive",false).commit();
        context.getSharedPreferences("portable",0).edit().clear().commit();LibrarySnapshot.write(context,"folders\n"+LibrarySnapshot.source(folders,false),tracks);
        PortablePlayerActivity preview=(PortablePlayerActivity)startActivitySync(new Intent(context,PortablePlayerActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK));
        android.webkit.WebView web=(android.webkit.WebView)field(preview,"web");boolean ready=false;for(int i=0;i<80;i++){if("162".equals(javascript(web,"document.querySelector('.mv-song-list>div')?.style.height==='11664px'?162:0"))){ready=true;break;}SystemClock.sleep(150);}check(ready,"Shared player did not load authorized library");
        check("true".equals(javascript(web,"document.querySelector('.mv-song').click();true")),"Shared song click failed");SystemClock.sleep(700);
        check("true".equals(javascript(web,"document.querySelector('.mv-song img')?.naturalWidth>0")),"Shared authorized cover endpoint did not decode artwork");
        final PortablePlayerActivity initialPreview=preview;main(()->{PlaybackService service=(PlaybackService)field(initialPreview,"playback");check(service!=null&&service.current()!=null&&service.current().id==first.id,"Shared play did not reach real service");});
        javascript(web,"document.querySelector('.mv-now').click();true");SystemClock.sleep(200);
        check(javascript(web,"document.querySelector('.mv-lyric-lines').textContent").contains("Translation"),"Shared bilingual lyrics missing");
        javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(200);
        for(String style:new String[]{"简易","音乐库","音乐墙"}){javascript(web,"Array.from(document.querySelectorAll('.mv-style-picker button')).find(x=>x.textContent==='"+style+"').click();true");SystemClock.sleep(200);check("true".equals(javascript(web,"!!document.querySelector('.mv-drawer')")),"Shared style switch closed drawer");}
        javascript(web,"Array.from(document.querySelectorAll('.mv-style-picker button')).find(x=>x.textContent==='音乐库').click();document.querySelector('[aria-label=\"深色模式\"]').click();true");SystemClock.sleep(200);javascript(web,"document.querySelector('[aria-label=\"关闭侧边栏\"]').click();true");SystemClock.sleep(200);check(javascript(web,"document.querySelector('main').dataset.theme").contains("dark"),"Shared theme not restored");
        javascript(web,"document.querySelector('.mv-back').click();true");SystemClock.sleep(300);
        javascript(web,"document.querySelector('.mv-song-list').scrollTop=413;true");SystemClock.sleep(700);String before=javascript(web,"document.querySelector('.mv-song-list').scrollTop");check(near(before,"413"),"Shared fixture did not scroll: "+before+" "+javascript(web,"JSON.stringify({body:document.querySelector('.mv-body').className,style:document.querySelector('main').dataset.style,height:document.querySelector('.mv-song-list').clientHeight,scroll:document.querySelector('.mv-song-list').scrollHeight,error:document.querySelector('.mv-error')?.textContent})"));SystemClock.sleep(1000);check(near(before,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Polling reset shared scroll");
        javascript(web,"document.querySelector('.mv-now').click();true");SystemClock.sleep(200);javascript(web,"document.querySelector('.mv-back').click();true");SystemClock.sleep(250);check(near(before,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Hidden playback page overwrote list anchor");
        javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(150);javascript(web,"Array.from(document.querySelectorAll('.mv-drawer nav button')).find(x=>x.textContent==='歌手').click();true");SystemClock.sleep(450);
        javascript(web,"document.querySelector('.mv-song-list').scrollTop=767;true");SystemClock.sleep(400);String parentAnchor=javascript(web,"document.querySelector('.mv-song-list').scrollTop");check(near(parentAnchor,"767"),"Shared artist fixture did not scroll");
        for(int cycle=0;cycle<3;cycle++){javascript(web,"Array.from(document.querySelectorAll('.mv-song')).find(x=>x.offsetTop>=document.querySelector('.mv-song-list').scrollTop).click();true");SystemClock.sleep(350);check("true".equals(javascript(web,"!!document.querySelector('.mv-back')")),"Shared artist group failed to open");javascript(web,"document.querySelector('.mv-back').click();true");SystemClock.sleep(350);check(near(parentAnchor,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Shared artist return lost anchor: "+parentAnchor+" -> "+javascript(web,"document.querySelector('.mv-song-list').scrollTop"));}
        javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(150);javascript(web,"Array.from(document.querySelectorAll('.mv-drawer nav button')).find(x=>x.textContent==='音乐库').click();true");SystemClock.sleep(350);check(near(before,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Shared library return lost anchor");
        javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(900);screenshot("shared-player-drawer-dark");javascript(web,"document.querySelector('[aria-label=\"关闭侧边栏\"]').click();true");
        main(preview::finish);SystemClock.sleep(300);preview=(PortablePlayerActivity)startActivitySync(new Intent(context,PortablePlayerActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));web=(android.webkit.WebView)field(preview,"web");SystemClock.sleep(1800);
        check(javascript(web,"document.querySelector('main')?.dataset.theme").contains("dark"),"Shared relaunch lost theme");check(near(before,javascript(web,"document.querySelector('.mv-song-list').scrollTop")),"Shared relaunch lost anchor");
        String favoriteId=javascript(web,"document.querySelector('.mv-song').dataset.songId").replace("\"","");boolean wasFavorite=context.getSharedPreferences("library",0).getStringSet("favorites",Collections.emptySet()).contains(favoriteId);javascript(web,"document.querySelector('.mv-song .mv-favorite').click();true");SystemClock.sleep(500);check(context.getSharedPreferences("library",0).getStringSet("favorites",Collections.emptySet()).contains(favoriteId)!=wasFavorite,"Shared favorite did not reach platform store");
        javascript(web,"document.querySelector('[aria-label=\"播放队列\"]').click();true");SystemClock.sleep(250);check(javascript(web,"document.querySelector('[role=dialog]').getAttribute('aria-label')").contains("播放队列"),"Shared queue did not open");javascript(web,"document.querySelector('[aria-label=\"关闭弹窗\"]').click();true");
        javascript(web,"document.querySelector('[aria-label=\"播放模式\"]').click();true");SystemClock.sleep(150);javascript(web,"Array.from(document.querySelectorAll('.mv-modal .mv-option')).find(x=>x.textContent.includes('单曲循环')).click();true");SystemClock.sleep(200);
        sliderContracts(web,preview);
        customScrollContracts(web);
        componentContracts(web);
        menuContracts(web);
        mobileCollections(web,context,tracks,preview);
        final PortablePlayerActivity checkedPreview=preview;main(()->check(((PlaybackService)field(checkedPreview,"playback")).mode==3,"Shared playback mode mapping incorrect"));
        javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(150);javascript(web,"Array.from(document.querySelectorAll('.mv-drawer nav button')).find(x=>x.textContent==='新建歌单').click();true");SystemClock.sleep(150);check(javascript(web,"document.querySelector('[role=dialog]').getAttribute('aria-label')").contains("新建歌单"),"Shared playlist editor did not open");javascript(web,"document.querySelector('[aria-label=\"关闭弹窗\"]').click();true");
        main(()->{PlaybackService service=(PlaybackService)field(checkedPreview,"playback");service.setMode(3);service.setQueue(tracks,0);});SystemClock.sleep(500);
        for(String style:new String[]{"简易","音乐库","音乐墙"})for(String theme:new String[]{"light","dark"}){
            javascript(web,"document.querySelector('[aria-label=\"打开侧边栏\"]').click();true");SystemClock.sleep(100);javascript(web,"Array.from(document.querySelectorAll('.mv-drawer .mv-style-picker button')).find(x=>x.textContent==='"+style+"').click();true");SystemClock.sleep(150);String target=theme.equals("dark")?"深色模式":"浅色模式";javascript(web,"document.querySelector('[aria-label=\""+target+"\"]')?.click();true");SystemClock.sleep(150);screenshot("shared-parity-drawer-"+style+"-"+theme);javascript(web,"document.querySelector('[aria-label=\"关闭侧边栏\"]').click();true");SystemClock.sleep(150);screenshot("shared-parity-page-"+style+"-"+theme);
        }
        check(near("0",javascript(web,"document.scrollingElement.scrollTop")),"Modal focus scrolled the fixed player shell");
        check("true".equals(javascript(web,"!!document.querySelector('.mv-cover-wall')")),"Music wall is still a list instead of cover canvas");String zoom=javascript(web,"document.querySelector('.mv-wall-plane').style.transform");javascript(web,"document.querySelector('[aria-label=\"放大音乐墙\"]').click();true");SystemClock.sleep(150);check(!zoom.equals(javascript(web,"document.querySelector('.mv-wall-plane').style.transform")),"Shared wall zoom failed");javascript(web,"document.querySelector('.mv-wall-card[data-wall-id=\""+first.id+"\"]').click();true");SystemClock.sleep(500);check("true".equals(javascript(web,"document.querySelector('.mv-body').classList.contains('show-player')")),"Shared wall focus failed");check("true".equals(javascript(web,"!!document.querySelector('.mv-wall-focused') && getComputedStyle(document.querySelector('.mv-player-page')).display==='none'")),"Wall focus must stay in tessellation, not overlay player page");check("true".equals(javascript(web,"new Set(Array.from(document.querySelectorAll('.mv-wall-card')).map(x=>Math.round(x.getBoundingClientRect().width))).size>1")),"Wall must use weighted cover sizes");SystemClock.sleep(550);check("true".equals(javascript(web,"(()=>{const view=document.querySelector('.mv-wall-focused .mv-lyric-lines'),active=view.querySelector('[data-active=true]');if(!active)return false;const a=active.getBoundingClientRect(),b=view.getBoundingClientRect();return a.top>=b.top-2 && a.bottom<=b.bottom+2 && Math.abs((a.top+a.bottom-b.top-b.bottom)/2)<24})()")),"Focused wall lyric must remain inside the visible viewport");screenshot("shared-parity-wall-focus");
        javascript(web,"window.wallPreviousTrack=document.querySelector('.mv-dock .mv-now strong').textContent;const card=Array.from(document.querySelectorAll('.mv-wall-card')).find(x=>x.dataset.wallId!=='"+first.id+"');window.wallPreviewTitle=card.querySelector('strong').textContent;card.click();true");SystemClock.sleep(700);
        check("true".equals(javascript(web,"document.querySelector('.mv-dock .mv-now strong').textContent===window.wallPreviousTrack && document.querySelector('.mv-wall-focused h1').textContent===window.wallPreviewTitle && !!document.querySelector('[aria-label=\"播放这首歌曲\"]')")),"Single wall tap must focus the selected cover without changing playback");

        final PortablePlayerActivity last=preview;main(()->{PlaybackService service=(PlaybackService)field(last,"playback");if(service!=null&&service.isPlaying())service.toggle();last.finish();});
        report.append("PASS shared WebView load, real WAV playback, bilingual lyrics, three styles, theme, polling and relaunch anchors\n");
    }
    private void tap(View view){tap(view,view.getWidth()/2f,view.getHeight()/2f);}
    private void tap(View view,float x,float y){int[] location=new int[2];main(()->view.getLocationOnScreen(location));long now=SystemClock.uptimeMillis();pointer(now,now,MotionEvent.ACTION_DOWN,x+location[0],y+location[1]);pointer(now,now+70,MotionEvent.ACTION_UP,x+location[0],y+location[1]);}
    private void swipe(View view,float sx,float sy,float ex,float ey){int[] location=new int[2];main(()->view.getLocationOnScreen(location));float x=location[0]+view.getWidth()*sx,y=location[1]+view.getHeight()*sy,dx=view.getWidth()*(ex-sx),dy=view.getHeight()*(ey-sy);long now=SystemClock.uptimeMillis();pointer(now,now,0,x,y);for(int i=1;i<=15;i++){SystemClock.sleep(20);pointer(now,SystemClock.uptimeMillis(),2,x+dx*i/15,y+dy*i/15);}SystemClock.sleep(80);pointer(now,SystemClock.uptimeMillis(),1,x+dx,y+dy);}
    private void pointer(long down,long event,int action,float x,float y){MotionEvent motion=MotionEvent.obtain(down,event,action,x,y,0);sendPointerSync(motion);motion.recycle();}
    private static boolean near(String first,String second){try{return Math.abs(Double.parseDouble(first)-Double.parseDouble(second))<=1;}catch(Exception ignored){return false;}}
    private static void check(boolean value,String message){if(!value)throw new AssertionError(message);}
}
