package com.xcosmos.minivoice;

import android.animation.*;
import android.content.Context;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.os.Parcelable;
import android.view.*;
import android.widget.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.*;

/** Native library and simple workspaces, sharing playback but retaining their own navigation. */
final class PlayerStylePage extends FrameLayout {
    interface BatchActions {void favorite(List<Song> songs,boolean value);void playlist(List<Song> songs);void removeFromPlaylist(List<Song> songs);void clearRecent();}
    private BatchActions batch;
    void setBatchActions(BatchActions value){batch=value;}
    private final SongSelection selection=new SongSelection();
    private boolean selecting;
    private HorizontalScrollView selectionBar;
    private TextView selectionCount,selectionAll,selectionFavorite,selectionPlaylist,selectionRemove,selectionToggle,summary;
    private ValueAnimator selectionMotion;
    private Picture groupSnapshot;private RectF groupOrigin;private String groupParentKey,groupChildKey;private boolean closingGroup;
    private BiConsumer<String,Boolean> sort;
    private String sortField;private boolean sortAscending;
    private LinearLayout columnHeader;
    private LibraryColumns columns=new LibraryColumns(0,1);
    void setSortAction(BiConsumer<String,Boolean> action){sort=action;}
    void setSorting(String field,boolean ascending){sortField=field;sortAscending=ascending;refreshColumnHeader();}
    private Consumer<Song> songMenu,favorite;
    private Runnable back=()->{},options=()->{},queue=()->{};
    private final Consumer<Song> play;private final IntConsumer seek;private final Runnable lyricsAction,browse;
    private List<Song> songs=new ArrayList<>();private List<Lyrics.Line> lyrics=Collections.emptyList();private Song current;
    private Set<String> favorites=Collections.emptySet();private AppAppearance.Palette colors=new AppAppearance.Palette(false);
    private String style="wall",section="音乐库",pageKey="音乐库",group;private boolean grouped,expanded,wide,playing,catalogOpen,navigationPending;
    private AbsListView list;private TextView listHeading,title,artist,nowPlaying;private ImageView cover;
    private LinearLayout libraryRoot,detailRoot,hero;private FrameLayout lyricPanel,heroSlot;private NativeLyricsView lyricView;
    private int position,duration,insetLeft,insetTop,insetRight,insetBottom,renderWidth,renderHeight,heroExtent;
    private String lyricStatus="暂无歌词";private ValueAnimator heroMotion;private int transitionEpoch,artGeneration;
    private final Map<String,Parcelable> scrollStates=new HashMap<>();
    private final Set<String> pending=new HashSet<>();
    private ThreadPoolExecutor images,detailImages;
    private final BaseAdapter adapter=new BaseAdapter(){
        public int getCount(){return songs.size();}public Song getItem(int index){return songs.get(index);}public long getItemId(int index){return getItem(index).id;}
        public View getView(int index,View recycled,ViewGroup parent){
            LinearLayout row;ImageView image;TextView caption,subtitle,star,more;
            if(recycled==null){
                row=new LinearLayout(getContext());row.setDescendantFocusability(FOCUS_BLOCK_DESCENDANTS);row.setOrientation(grouped?LinearLayout.VERTICAL:LinearLayout.HORIZONTAL);row.setGravity(Gravity.CENTER_VERTICAL);row.setPadding(dp(12),dp(8),dp(12),dp(8));
                image=new ImageView(getContext());image.setScaleType(ImageView.ScaleType.CENTER_CROP);image.setBackground(shape(colors.line,12));image.setClipToOutline(true);row.addView(image,new LinearLayout.LayoutParams(grouped?-1:dp(46),grouped?dp(wide?164:134):dp(46)));
                LinearLayout labels=new LinearLayout(getContext());labels.setOrientation(LinearLayout.VERTICAL);labels.setPadding(grouped?0:dp(12),grouped?dp(10):0,dp(6),0);row.addView(labels,grouped?new LinearLayout.LayoutParams(-1,-2):new LinearLayout.LayoutParams(0,-2,1));
                caption=text("",15,colors.text);caption.setTypeface(null,Typeface.BOLD);caption.setSingleLine(true);caption.setEllipsize(android.text.TextUtils.TruncateAt.END);
                subtitle=text("",12,colors.secondary);subtitle.setSingleLine(true);subtitle.setEllipsize(android.text.TextUtils.TruncateAt.END);subtitle.setPadding(0,dp(4),0,0);labels.addView(caption);labels.addView(subtitle);
                TextView artistCell=text("",13,colors.secondary),albumCell=text("",13,colors.secondary);artistCell.setSingleLine(true);albumCell.setSingleLine(true);artistCell.setEllipsize(android.text.TextUtils.TruncateAt.END);albumCell.setEllipsize(android.text.TextUtils.TruncateAt.END);
                if(!grouped){row.addView(artistCell,new LinearLayout.LayoutParams(columns.artist,dp(48)));row.addView(albumCell,new LinearLayout.LayoutParams(columns.album,dp(48)));}artistCell.setGravity(Gravity.CENTER_VERTICAL);albumCell.setGravity(Gravity.CENTER_VERTICAL);
                star=tool("♡",()->{});more=tool("⋮",()->{});if(!grouped){row.addView(star,new LinearLayout.LayoutParams(dp(40),dp(48)));row.addView(more,new LinearLayout.LayoutParams(dp(36),dp(48)));}
                CheckBox check=new CheckBox(getContext());check.setButtonTintList(android.content.res.ColorStateList.valueOf(colors.accent));check.setContentDescription("选择歌曲");if(!grouped)row.addView(check,0,new LinearLayout.LayoutParams(dp(40),dp(48)));
                TextView length=text("",11,colors.secondary);length.setGravity(Gravity.CENTER);if(!grouped)row.addView(length,new LinearLayout.LayoutParams(dp(42),dp(48)));
                row.setTag(new Object[]{image,caption,subtitle,star,more,check,length,artistCell,albumCell});
            }else row=(LinearLayout)recycled;
            Object[] holder=(Object[])row.getTag();image=(ImageView)holder[0];caption=(TextView)holder[1];subtitle=(TextView)holder[2];star=(TextView)holder[3];more=(TextView)holder[4];Song song=getItem(index);
            TextView artistCell=(TextView)holder[7],albumCell=(TextView)holder[8];artistCell.setText(song.artist);albumCell.setText(song.album);artistCell.setTextColor(colors.secondary);albumCell.setTextColor(colors.secondary);subtitle.setVisibility(!grouped&&columns.artist>0&&columns.album>0?GONE:VISIBLE);
            CheckBox check=(CheckBox)holder[5];check.setOnCheckedChangeListener(null);check.setVisibility(selecting?VISIBLE:GONE);check.setChecked(selection.contains(song.id));check.setContentDescription("选择 "+song.title);check.setOnCheckedChangeListener((button,value)->toggleSelection(song.id));
            TextView length=(TextView)holder[6];length.setText(String.format(java.util.Locale.ROOT,"%d:%02d",song.duration/60000,(song.duration/1000)%60));length.setVisibility(grouped||selecting?GONE:VISIBLE);
            star.setVisibility(selecting?GONE:VISIBLE);more.setVisibility(selecting?GONE:VISIBLE);
            bindImage(image,song,grouped?512:256);caption.setText(song.title);subtitle.setText(grouped?song.groupCount+" 首歌曲":(columns.artist>0?song.album:song.artist+" · "+song.album));caption.setTextColor(current!=null&&current.id==song.id&&!grouped?colors.accent:colors.text);subtitle.setTextColor(colors.secondary);
            row.setBackground(shape(!grouped&&(selecting?selection.contains(song.id):current!=null&&current.id==song.id)?colors.line:Color.TRANSPARENT,12));
            star.setText(favorites.contains(Long.toString(song.id))?"♥":"♡");star.setTextColor(colors.accent);star.setContentDescription("收藏 "+song.title);star.setOnClickListener(v->{if(favorite!=null)favorite.accept(song);});more.setContentDescription(song.title+"的更多操作");more.setOnClickListener(v->{if(songMenu!=null)songMenu.accept(song);});return row;
        }
    };
    PlayerStylePage(Context context,Consumer<Song> play,IntConsumer seek,Runnable lyricsAction,Runnable browse){super(context);this.play=play;this.seek=seek;this.lyricsAction=lyricsAction;this.browse=browse;setVisibility(GONE);}
    private int dp(float value){return Math.round(value*getResources().getDisplayMetrics().density);}
    private TextView text(String value,int size,int color){TextView view=new TextView(getContext());view.setText(value);view.setTextSize(size);view.setTextColor(color);return view;}
    private GradientDrawable shape(int color,int radius){GradientDrawable shape=new GradientDrawable();shape.setColor(color);shape.setCornerRadius(dp(radius));return shape;}
    private TextView tool(String caption,Runnable action){TextView view=text(caption,16,colors.accent);view.setGravity(Gravity.CENTER);view.setMinHeight(dp(44));view.setPadding(dp(8),0,dp(8),0);view.setOnClickListener(v->action.run());ButtonFeedback.install(view);return view;}
    void setSongMenu(Consumer<Song> value){songMenu=value;}
    void setTools(Runnable back,Runnable options,Runnable queue,Consumer<Song> favorite){this.back=back;this.options=options;this.queue=queue;this.favorite=favorite;}
    void setFavorites(Set<String> value){if(favorites.equals(value))return;favorites=new HashSet<>(value);adapter.notifyDataSetChanged();updateSelection();}
    void configure(String value,AppAppearance.Palette palette){
        boolean changed=!style.equals(value),themeChanged=colors.dark!=palette.dark;saveScroll();style=value;colors=palette;
        if(changed){expanded=false;catalogOpen=false;selecting=false;selection.clear();}setBackgroundColor(colors.background);
        setVisibility(style.equals("wall")?GONE:VISIBLE);
        if(style.equals("wall")){artGeneration++;pending.clear();if(images!=null)images.getQueue().clear();if(detailImages!=null)detailImages.getQueue().clear();}
        if(!style.equals("wall")&&(changed||themeChanged||getChildCount()==0)){render();if(changed)enter(this,14);}
    }
    void setInsets(int left,int top,int right,int bottom){insetLeft=left;insetTop=top;insetRight=right;insetBottom=bottom;boolean footerWide=(getWidth()>0?getWidth():getResources().getDisplayMetrics().widthPixels)-left-right>=dp(620);setPadding(left,top+dp(80),right,bottom+dp(footerWide?104:120));}
    void setSongs(List<Song> value){boolean nextGrouped=!value.isEmpty()&&value.get(0).groupCount>0;boolean layoutChanged=nextGrouped!=grouped;boolean same=value.size()==songs.size();if(same)for(int i=0;i<value.size();i++)if(value.get(i)!=songs.get(i)){same=false;break;}if(same&&!layoutChanged){updateHeading();return;}grouped=nextGrouped;if(grouped){selecting=false;selection.clear();}songs=new ArrayList<>(value);selection.retain(visibleIDs());if(layoutChanged&&!style.equals("wall"))render();else adapter.notifyDataSetChanged();updateHeading();updateSelection();}
    void setSection(String value){section=value.equals("歌曲")?"音乐库":value.startsWith("歌单:")?value.substring(3):value;updateHeading();}
    void preparePage(String key){if(pageKey.equals(key))return;saveScroll();selecting=false;selection.clear();if(!key.equals(groupParentKey)&&!key.equals(groupChildKey))clearGroupTransition();pageKey=key;int split=key.indexOf('\n');group=split<0||split==key.length()-1?null:key.substring(split+1);navigationPending=true;}
    void setBrowseContext(String group,String section){
        String key=section+"\n"+(group==null?"":group);boolean changed=navigationPending||!pageKey.equals(key);navigationPending=false;if(!pageKey.equals(key))saveScroll();pageKey=key;this.group=group;setSection(group==null?section:group);
        if(changed&&!style.equals("wall")){if(style.equals("library"))expanded=false;render();if(libraryRoot!=null&&libraryRoot.getVisibility()==VISIBLE){if(group!=null&&pageKey.equals(groupChildKey)&&groupSnapshot!=null)openGroupTransition();else enter(libraryRoot,group==null?-18:18);}if(group==null)clearGroupTransition();}
    }
    void setSong(Song song){boolean changed=current==null||current.id!=song.id||!Objects.equals(current.artworkVersion,song.artworkVersion);current=song;if(changed){lyrics=Collections.emptyList();lyricStatus="正在加载歌词…";if(lyricView!=null){lyricView.lyrics(lyrics);lyricView.status(lyricStatus);}updateDetails();adapter.notifyDataSetChanged();}}
    void setLyricsStatus(String value){lyricStatus=value;if(lyricView!=null)lyricView.status(value);}
    void setLyrics(List<Lyrics.Line> value){lyrics=value;if(lyricView!=null)lyricView.lyrics(value);}
    void setPosition(int value){setPlayback(value,duration,playing);}
    void setPlayback(int value,int duration,boolean playing){position=value;this.duration=duration;this.playing=playing;if(lyricView!=null)lyricView.playback(value,duration,playing);}
    void locate(long id){if(style.equals("library")&&expanded)setExpanded(false);if(list!=null)for(int i=0;i<songs.size();i++)if(songs.get(i).id==id){list.smoothScrollToPosition(i);break;}}
    boolean collapse(){if(selecting){setSelecting(false);return true;}if(group!=null&&(style.equals("library")&&!expanded||style.equals("simple")&&catalogOpen)){closeGroupTransition();return true;}if(style.equals("simple")&&catalogOpen){showPlayer();return true;}if(!expanded)return false;setExpanded(false);return true;}
    void showCatalog(){if(!style.equals("simple"))return;catalogOpen=true;if(libraryRoot!=null){detailRoot.setVisibility(GONE);libraryRoot.setVisibility(VISIBLE);enter(libraryRoot,18);}}
    void showPlayer(){if(!style.equals("simple"))return;catalogOpen=false;if(detailRoot!=null){libraryRoot.setVisibility(GONE);detailRoot.setVisibility(VISIBLE);enter(detailRoot,-14);updateDetails();}}
    void toggleExpanded(){if(current!=null)setExpanded(!expanded);}
    private void updateHeading(){
        if(listHeading!=null)listHeading.setText(section);
        if(summary!=null){long total=0;for(Song song:songs)total+=song.duration;summary.setText(songs.size()+(grouped?" 项": " 首 · "+(total/3600000>0?total/3600000+" 小时 ":"")+(total/60000%60)+" 分钟"));}
    }
    private List<Long> visibleIDs(){List<Long> ids=new ArrayList<>();for(Song song:songs)if(song.groupCount==0)ids.add(song.id);return ids;}
    private List<Song> selectedSongs(){List<Song> result=new ArrayList<>();for(Song song:songs)if(selection.contains(song.id))result.add(song);return result;}
    private boolean allFavorite(){List<Song> selected=selectedSongs();if(selected.isEmpty())return false;for(Song song:selected)if(!favorites.contains(Long.toString(song.id)))return false;return true;}
    private void toggleSelection(long id){selection.toggle(id);adapter.notifyDataSetChanged();updateSelection();}
    private void updateSelection(){
        if(selectionCount==null)return;selectionCount.setText("已选 "+selection.size()+" 首");selectionAll.setText(selection.all(visibleIDs())?"取消全选":"全选");selectionFavorite.setText(allFavorite()?"取消收藏":"收藏");boolean enabled=selection.size()>0;
        for(TextView item:new TextView[]{selectionFavorite,selectionPlaylist,selectionRemove}){item.setEnabled(enabled);item.setAlpha(enabled?1:.4f);}
        if(selectionToggle!=null)selectionToggle.setText(selecting?"完成":"多选");refreshColumnHeader();
    }
    private void refreshColumnHeader(){
        if(columnHeader==null)return;columnHeader.removeAllViews();View leading=new View(getContext());columnHeader.addView(leading,new LinearLayout.LayoutParams(dp(58+(selecting?40:0)),1));
        column("歌曲","title",0,1);column("歌手","artist",columns.artist,0);if(columns.album>0)column("专辑","album",columns.album,0);
        if(!selecting){columnHeader.addView(new View(getContext()),new LinearLayout.LayoutParams(dp(76),1));TextView duration=text("时长",11,colors.secondary);duration.setGravity(Gravity.CENTER);columnHeader.addView(duration,new LinearLayout.LayoutParams(dp(42),-1));}
    }
    private void column(String caption,String field,int width,float weight){
        TextView view=text(caption+(field.equals(sortField)?sortAscending?" ↑":" ↓":""),12,field.equals(sortField)?colors.accent:colors.secondary);view.setGravity(Gravity.CENTER_VERTICAL);columnHeader.addView(view,new LinearLayout.LayoutParams(width,-1,weight));view.setEnabled(sort!=null&&sortField!=null);view.setOnClickListener(v->{if(sort!=null)sort.accept(field,field.equals(sortField)?!sortAscending:true);});ButtonFeedback.install(view);
    }
    private void setSelecting(boolean value){
        if(grouped||selecting==value)return;selecting=value;if(!value)selection.clear();adapter.notifyDataSetChanged();updateSelection();
        if(selectionBar==null)return;if(selectionMotion!=null)selectionMotion.cancel();selectionBar.setVisibility(VISIBLE);android.view.ViewGroup.LayoutParams params=selectionBar.getLayoutParams();int start=Math.max(0,params.height),end=value?dp(48):0;
        selectionMotion=ValueAnimator.ofInt(start,end);selectionMotion.setDuration(animations()?200:0);selectionMotion.addUpdateListener(a->{int height=(int)a.getAnimatedValue();params.height=height;selectionBar.setLayoutParams(params);selectionBar.setAlpha(height/(float)dp(48));});selectionMotion.addListener(new AnimatorListenerAdapter(){@Override public void onAnimationEnd(Animator animator){if(!selecting)selectionBar.setVisibility(GONE);}});selectionMotion.start();
    }
    private void captureGroup(View card,String name){
        clearGroupTransition();if(!animations()||libraryRoot==null||libraryRoot.getWidth()==0||libraryRoot.getHeight()==0)return;
        int[] origin=new int[2],base=new int[2];card.getLocationInWindow(origin);libraryRoot.getLocationInWindow(base);
        groupOrigin=new RectF(origin[0]-base[0],origin[1]-base[1],origin[0]-base[0]+card.getWidth(),origin[1]-base[1]+card.getHeight());
        groupParentKey=pageKey;groupChildKey=pageKey+name;Picture picture=new Picture();try{Canvas recording=picture.beginRecording(libraryRoot.getWidth(),libraryRoot.getHeight());try{libraryRoot.draw(recording);}finally{picture.endRecording();}groupSnapshot=picture;}catch(RuntimeException|OutOfMemoryError unavailable){clearGroupTransition();}
    }
    private View addGroupBackdrop(){
        final Picture picture=groupSnapshot;View backdrop=new View(getContext()){@Override protected void onDraw(Canvas canvas){super.onDraw(canvas);if(picture!=null)canvas.drawPicture(picture,new Rect(0,0,getWidth(),getHeight()));}};
        addView(backdrop,0,new LayoutParams(-1,-1));return backdrop;
    }
    private void openGroupTransition(){
        final int epoch=transitionEpoch;final LinearLayout panel=libraryRoot;final RectF origin=new RectF(groupOrigin);final View backdrop=addGroupBackdrop();panel.setClickable(true);panel.setAlpha(0);
        panel.post(()->{if(epoch!=transitionEpoch||groupSnapshot==null)return;panel.animate().cancel();panel.setPivotX(0);panel.setPivotY(0);panel.setTranslationX(origin.left);panel.setTranslationY(origin.top);panel.setScaleX(origin.width()/Math.max(1,panel.getWidth()));panel.setScaleY(origin.height()/Math.max(1,panel.getHeight()));panel.setAlpha(.25f);panel.animate().translationX(0).translationY(0).scaleX(1).scaleY(1).alpha(1).setDuration(280).setInterpolator(new android.view.animation.DecelerateInterpolator()).withEndAction(()->{if(epoch==transitionEpoch)removeView(backdrop);}).start();});
    }
    private void closeGroupTransition(){
        if(closingGroup)return;if(groupSnapshot==null||groupOrigin==null||!animations()||libraryRoot==null){back.run();return;}
        closingGroup=true;int epoch=++transitionEpoch;libraryRoot.animate().cancel();addGroupBackdrop();libraryRoot.setPivotX(0);libraryRoot.setPivotY(0);libraryRoot.animate().translationX(groupOrigin.left).translationY(groupOrigin.top).scaleX(groupOrigin.width()/Math.max(1,libraryRoot.getWidth())).scaleY(groupOrigin.height()/Math.max(1,libraryRoot.getHeight())).alpha(0).setDuration(240).setInterpolator(new android.view.animation.AccelerateDecelerateInterpolator()).withEndAction(()->{if(epoch==transitionEpoch){closingGroup=false;back.run();}}).start();
    }
    private void clearGroupTransition(){groupSnapshot=null;groupOrigin=null;groupParentKey=null;groupChildKey=null;}
    private void saveScroll(){if(list!=null)scrollStates.put(pageKey,list.onSaveInstanceState());}
    private void enter(View view,float shift){view.animate().cancel();if(!animations()){view.setAlpha(1);view.setTranslationY(0);return;}view.setAlpha(0);view.setTranslationY(dp(shift));view.animate().alpha(1).translationY(0).setDuration(280).setInterpolator(new android.view.animation.DecelerateInterpolator()).start();}
    private boolean animations(){return ValueAnimator.areAnimatorsEnabled();}
    private void render(){
        transitionEpoch++;closingGroup=false;if(libraryRoot!=null)libraryRoot.animate().cancel();if(heroMotion!=null){heroMotion.cancel();heroMotion=null;}if(selectionMotion!=null){selectionMotion.removeAllListeners();selectionMotion.cancel();selectionMotion=null;}animate().cancel();setAlpha(1);setTranslationY(0);removeAllViews();artGeneration++;pending.clear();if(images!=null)images.getQueue().clear();if(detailImages!=null)detailImages.getQueue().clear();
        list=null;listHeading=null;selectionBar=null;selectionCount=null;selectionToggle=null;summary=null;columnHeader=null;cover=null;title=null;artist=null;nowPlaying=null;lyricView=null;hero=null;libraryRoot=null;detailRoot=null;
        if(style.equals("wall"))return;
        wide=getWidth()-getPaddingLeft()-getPaddingRight()>dp(620);columns=new LibraryColumns(getWidth()-getPaddingLeft()-getPaddingRight(),getResources().getDisplayMetrics().density);
        buildLibrary();buildDetails();
        boolean showingDetail=style.equals("simple")?!catalogOpen:expanded;
        detailRoot.setVisibility(showingDetail?VISIBLE:GONE);libraryRoot.setVisibility(showingDetail?GONE:VISIBLE);
        updateDetails();updateHeading();
    }
    private void buildLibrary(){
        libraryRoot=new LinearLayout(getContext());libraryRoot.setOrientation(LinearLayout.VERTICAL);addView(libraryRoot,new LayoutParams(-1,-1));
        LinearLayout toolbar=new LinearLayout(getContext());toolbar.setGravity(Gravity.CENTER_VERTICAL);toolbar.setPadding(dp(12),dp(4),dp(8),dp(8));libraryRoot.addView(toolbar);
        if(group!=null||style.equals("simple")){PageBackButton arrow=new PageBackButton(getContext(),colors.accent,group!=null?this::closeGroupTransition:this::showPlayer);toolbar.addView(arrow,new LinearLayout.LayoutParams(dp(44),dp(44)));}
        listHeading=text("",22,colors.text);listHeading.setSingleLine(true);listHeading.setEllipsize(android.text.TextUtils.TruncateAt.END);listHeading.setTypeface(null,Typeface.BOLD);toolbar.addView(listHeading,new LinearLayout.LayoutParams(0,-2,1));toolbar.addView(tool(section.equals("最近播放")?"清空":"排序",()->{if(section.equals("最近播放")){if(batch!=null)batch.clearRecent();}else options.run();}));
        if(!grouped){selectionToggle=tool(selecting?"完成":"多选",()->setSelecting(!selecting));toolbar.addView(selectionToggle);}
        LinearLayout info=new LinearLayout(getContext());info.setGravity(Gravity.CENTER_VERTICAL);info.setPadding(dp(20),0,dp(12),0);libraryRoot.addView(info,new LinearLayout.LayoutParams(-1,dp(40)));summary=text("",12,colors.secondary);info.addView(summary,new LinearLayout.LayoutParams(0,-1,1));
        if(!grouped)info.addView(tool("播放全部",()->{if(!songs.isEmpty())play.accept(songs.get(0));}));
        selectionBar=new HorizontalScrollView(getContext());selectionBar.setHorizontalScrollBarEnabled(false);selectionBar.setBackground(shape(colors.surface,12));libraryRoot.addView(selectionBar,new LinearLayout.LayoutParams(-1,selecting?dp(48):0));selectionBar.setVisibility(selecting?VISIBLE:GONE);
        LinearLayout batchRow=new LinearLayout(getContext());batchRow.setGravity(Gravity.CENTER_VERTICAL);batchRow.setPadding(dp(12),0,dp(12),0);selectionBar.addView(batchRow,new HorizontalScrollView.LayoutParams(-2,dp(48)));
        selectionCount=text("",13,colors.secondary);batchRow.addView(selectionCount);selectionAll=tool("全选",()->{selection.toggleAll(visibleIDs());adapter.notifyDataSetChanged();updateSelection();});selectionFavorite=tool("收藏",()->{if(batch!=null)batch.favorite(selectedSongs(),!allFavorite());});selectionPlaylist=tool("加入歌单",()->{if(batch!=null)batch.playlist(selectedSongs());});selectionRemove=tool("从歌单移除",()->{if(batch!=null)batch.removeFromPlaylist(selectedSongs());});
        batchRow.addView(selectionAll);batchRow.addView(selectionFavorite);batchRow.addView(selectionPlaylist);if(pageKey.startsWith("歌单:"))batchRow.addView(selectionRemove);updateSelection();
        nowPlaying=tool("",()->{if(style.equals("simple"))showPlayer();else toggleExpanded();});nowPlaying.setSingleLine(true);nowPlaying.setEllipsize(android.text.TextUtils.TruncateAt.END);nowPlaying.setGravity(Gravity.START|Gravity.CENTER_VERTICAL);nowPlaying.setPadding(dp(20),0,dp(20),0);nowPlaying.setBackground(shape(colors.surface,12));libraryRoot.addView(nowPlaying,new LinearLayout.LayoutParams(-1,dp(48)));
        if(!grouped&&columns.artist>0){columnHeader=new LinearLayout(getContext());columnHeader.setGravity(Gravity.CENTER_VERTICAL);columnHeader.setPadding(dp(20),0,dp(20),0);libraryRoot.addView(columnHeader,new LinearLayout.LayoutParams(-1,dp(32)));refreshColumnHeader();}
        FrameLayout results=new FrameLayout(getContext());libraryRoot.addView(results,new LinearLayout.LayoutParams(-1,0,1));
        if(grouped){GridView grid=new GridView(getContext());grid.setNumColumns(wide?3:2);grid.setHorizontalSpacing(dp(8));grid.setVerticalSpacing(dp(8));grid.setStretchMode(GridView.STRETCH_COLUMN_WIDTH);list=grid;}else{ListView tracks=new ListView(getContext());tracks.setDivider(null);list=tracks;}
        list.setCacheColorHint(0);list.setPadding(dp(8),dp(8),dp(8),dp(16));list.setClipToPadding(false);list.setAdapter(adapter);results.addView(list,new LayoutParams(-1,-1));
        list.setOnItemClickListener((parent,view,index,id)->{if(selecting)toggleSelection(songs.get(index).id);else{if(grouped)captureGroup(view,songs.get(index).title);play.accept(songs.get(index));}});list.setOnItemLongClickListener((parent,view,index,id)->{Song song=songs.get(index);if(grouped||songMenu==null)return false;if(selecting)toggleSelection(song.id);else songMenu.accept(song);return true;});
        TextView empty=text(section.equals("收藏")?"暂无收藏\n点按歌曲旁的爱心添加":section.equals("最近播放")?"还没有播放记录":pageKey.startsWith("歌单:")?"歌单还没有歌曲\n可从歌曲菜单或多选工具栏添加":"暂无歌曲\n可在设置中添加音乐文件夹",15,colors.secondary);empty.setGravity(Gravity.CENTER);results.addView(empty,new LayoutParams(-1,-1));list.setEmptyView(empty);
        Parcelable saved=scrollStates.get(pageKey);if(saved!=null)list.onRestoreInstanceState(saved);
    }
    private void buildDetails(){
        detailRoot=new LinearLayout(getContext());detailRoot.setOrientation(LinearLayout.VERTICAL);detailRoot.setBackgroundColor(colors.background);addView(detailRoot,new LayoutParams(-1,-1));
        LinearLayout heading=new LinearLayout(getContext());heading.setGravity(Gravity.CENTER_VERTICAL);heading.setPadding(dp(16),0,dp(12),0);detailRoot.addView(heading,new LinearLayout.LayoutParams(-1,dp(44)));
        TextView name=text(style.equals("library")?"专辑播放":"正在播放",16,colors.secondary);heading.addView(name,new LinearLayout.LayoutParams(0,-1,1));TextView expand=tool(style.equals("library")?"返回音乐库":expanded?"收起歌词":"展开歌词",this::toggleExpanded);heading.addView(expand);if(style.equals("simple"))heading.addView(tool("歌曲",this::showCatalog));expand.setTag("expand");heading.addView(tool("队列",queue));
        LinearLayout workspace=new LinearLayout(getContext());workspace.setOrientation(wide?LinearLayout.HORIZONTAL:LinearLayout.VERTICAL);detailRoot.addView(workspace,new LinearLayout.LayoutParams(-1,0,1));
        hero=new LinearLayout(getContext());hero.setOrientation(LinearLayout.VERTICAL);hero.setGravity(Gravity.CENTER);hero.setPadding(dp(20),dp(8),dp(20),dp(8));
        int availableH=Math.max(1,getHeight()-getPaddingTop()-getPaddingBottom()-dp(44));
        PlayerWorkspaceMetrics metrics=new PlayerWorkspaceMetrics(Math.max(1,getWidth()-getPaddingLeft()-getPaddingRight()),availableH,getResources().getDisplayMetrics().density);
        int side=metrics.artwork;heroExtent=metrics.hero;
        boolean hidden=style.equals("simple")&&expanded;
        heroSlot=new FrameLayout(getContext());ScrollView heroScroll=new ScrollView(getContext());heroScroll.setFillViewport(true);heroScroll.setVerticalScrollBarEnabled(false);heroScroll.addView(hero,new ScrollView.LayoutParams(-1,-1));heroSlot.addView(heroScroll,new LayoutParams(-1,-1));
        workspace.addView(heroSlot,wide?new LinearLayout.LayoutParams(hidden?0:heroExtent,-1):new LinearLayout.LayoutParams(-1,hidden?0:heroExtent));hero.setAlpha(hidden?0:1);hero.setImportantForAccessibility(hidden?IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS:IMPORTANT_FOR_ACCESSIBILITY_AUTO);
        cover=new ImageView(getContext());cover.setScaleType(ImageView.ScaleType.CENTER_CROP);cover.setBackground(shape(colors.line,18));cover.setClipToOutline(true);cover.setContentDescription("展开或收起歌词");cover.setOnClickListener(v->toggleExpanded());ButtonFeedback.install(cover);hero.addView(cover,new LinearLayout.LayoutParams(side,side));
        title=text("",23,colors.text);title.setTypeface(null,Typeface.BOLD);title.setMaxLines(2);title.setEllipsize(android.text.TextUtils.TruncateAt.END);title.setGravity(Gravity.CENTER);title.setPadding(0,dp(12),0,0);hero.addView(title,new LinearLayout.LayoutParams(-1,-2));
        artist=text("",13,colors.secondary);artist.setGravity(Gravity.CENTER);artist.setMaxLines(2);artist.setEllipsize(android.text.TextUtils.TruncateAt.END);artist.setPadding(0,dp(6),0,0);hero.addView(artist,new LinearLayout.LayoutParams(-1,-2));
        lyricPanel=new FrameLayout(getContext());workspace.addView(lyricPanel,wide?new LinearLayout.LayoutParams(0,-1,1):new LinearLayout.LayoutParams(-1,0,1));
        lyricView=new NativeLyricsView(getContext(),seek,lyricsAction);lyricView.palette(colors);lyricView.lyrics(lyrics);lyricView.status(lyricStatus);lyricView.playback(position,duration,playing);lyricPanel.addView(lyricView,new LayoutParams(-1,-1));
        if(current==null){TextView choose=tool("选择歌曲 · 浏览音乐库",browse);hero.addView(choose);}
    }
    private void updateDetails(){
        if(title!=null)title.setText(current==null?"选择一首歌曲":current.title);
        if(artist!=null)artist.setText(current==null?"从音乐库开始播放":current.artist+" · "+current.album);
        if(nowPlaying!=null){nowPlaying.setText(current==null?"选择一首歌曲开始播放":"正在播放 · "+current.title+"  ›");nowPlaying.setEnabled(current!=null);}
        if(cover!=null&&current!=null)bindImage(cover,current,1600);
    }
    private void setExpanded(boolean value){
        if(expanded==value||style.equals("wall"))return;expanded=value;int epoch=++transitionEpoch;
        if(style.equals("library")){
            if(libraryRoot==null||detailRoot==null)return;View target=value?detailRoot:libraryRoot,source=value?libraryRoot:detailRoot;
            source.animate().cancel();target.animate().cancel();target.setVisibility(VISIBLE);if(value)updateDetails();target.setAlpha(animations()?0:1);target.setTranslationY(animations()?dp(value?28:-16):0);source.setEnabled(false);target.bringToFront();target.setClickable(true);
            if(!animations()){source.setVisibility(GONE);source.setEnabled(true);return;}
            source.animate().alpha(0).setDuration(180).withEndAction(()->{if(epoch==transitionEpoch){source.setVisibility(GONE);source.setEnabled(true);source.setAlpha(1);}}).start();
            target.setEnabled(true);target.animate().alpha(1).translationY(0).setDuration(320).setInterpolator(new android.view.animation.DecelerateInterpolator()).start();
        }else if(hero!=null){
            if(heroMotion!=null){heroMotion.cancel();heroMotion=null;}LinearLayout.LayoutParams params=(LinearLayout.LayoutParams)heroSlot.getLayoutParams();int start=wide?params.width:params.height,end=value?0:heroExtent;
            TextView toggle=detailRoot.findViewWithTag("expand");if(toggle!=null)toggle.setText(value?"收起歌词":"展开歌词");hero.setImportantForAccessibility(value?IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS:IMPORTANT_FOR_ACCESSIBILITY_AUTO);
            heroMotion=ValueAnimator.ofInt(start,end);heroMotion.setDuration(animations()?320:0);heroMotion.setInterpolator(new android.view.animation.DecelerateInterpolator());heroMotion.addUpdateListener(a->{int extent=(int)a.getAnimatedValue();if(wide)params.width=extent;else params.height=extent;heroSlot.setLayoutParams(params);hero.setAlpha(heroExtent==0?1:extent/(float)heroExtent);});heroMotion.start();
        }
    }
    private void bindImage(ImageView image,Song song,int side){
        String key=song.uri+"\n"+song.artworkUri+"\n"+song.artworkVersion+"\n"+side;image.setTag(key);Bitmap bitmap=ArtworkCache.peek(song,side);if(bitmap==null)bitmap=song.artworkPreview;image.setImageBitmap(bitmap);
        if(ArtworkCache.peek(song,side)!=null||!isShown()||pending.contains(key))return;
        if(images==null||images.isShutdown()){images=new ThreadPoolExecutor(1,1,10,TimeUnit.SECONDS,new ArrayBlockingQueue<>(16));images.allowCoreThreadTimeOut(true);}
        if(side>=1600&&(detailImages==null||detailImages.isShutdown())){detailImages=new ThreadPoolExecutor(1,1,10,TimeUnit.SECONDS,new ArrayBlockingQueue<>(2));detailImages.allowCoreThreadTimeOut(true);}
        ThreadPoolExecutor loader=side>=1600?detailImages:images;
        int generation=artGeneration;pending.add(key);try{loader.execute(()->{Bitmap result=null;try{result=ArtworkCache.load(getContext(),song,side);}catch(RuntimeException|OutOfMemoryError ignored){}final Bitmap ready=result;post(()->{if(generation!=artGeneration)return;pending.remove(key);if(ready!=null){if(key.equals(image.getTag()))image.setImageBitmap(ready);if(cover!=null&&key.equals(cover.getTag()))cover.setImageBitmap(ready);if(list!=null)for(int i=0;i<list.getChildCount();i++){Object holder=list.getChildAt(i).getTag();if(holder instanceof Object[]){ImageView thumbnail=(ImageView)((Object[])holder)[0];if(key.equals(thumbnail.getTag()))thumbnail.setImageBitmap(ready);}}}});});}catch(RejectedExecutionException busy){pending.remove(key);}
    }
    @Override protected void onSizeChanged(int w,int h,int oldw,int oldh){super.onSizeChanged(w,h,oldw,oldh);if(w>0&&h>0&&(w!=renderWidth||h!=renderHeight)){renderWidth=w;renderHeight=h;clearGroupTransition();saveScroll();post(()->{if(getWidth()==w&&getHeight()==h&&!style.equals("wall"))render();});}}
    @Override protected void onDetachedFromWindow(){transitionEpoch++;artGeneration++;clearGroupTransition();if(heroMotion!=null)heroMotion.cancel();if(selectionMotion!=null)selectionMotion.cancel();if(images!=null)images.shutdownNow();if(detailImages!=null)detailImages.shutdownNow();pending.clear();super.onDetachedFromWindow();}
}
