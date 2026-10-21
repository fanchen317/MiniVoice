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
    private Consumer<ImageView> songLaunch=image->{};
    void setSongLaunch(Consumer<ImageView> action){songLaunch=action;}
    private HomeScreen.Actions playbackActions;
    private SeekBar landscapeSeek;private TextView landscapeTime,landscapeTotal,landscapeMode;private TransportButton landscapePlay;private LibraryActionButton landscapeFavorite;
    void setPlaybackActions(HomeScreen.Actions value){playbackActions=value;}
    boolean landscapePlayback(){return !sidebarCatalog&&getResources().getConfiguration().orientation==android.content.res.Configuration.ORIENTATION_LANDSCAPE&&(style.equals("library")&&expanded||style.equals("simple")&&!catalogOpen);}
    boolean landscapeLibrary(){return !sidebarCatalog&&style.equals("library")&&landscapeLayout();}
    private boolean landscapeLayout(){return !sidebarCatalog&&getResources().getConfiguration().orientation==android.content.res.Configuration.ORIENTATION_LANDSCAPE;}
    private static final int CONTENT_GAP=8;
    private BatchActions batch;
    void setBatchActions(BatchActions value){batch=value;}
    private final SongSelection selection=new SongSelection();
    private boolean selecting,sidebarCatalog;
    void useSidebarCatalog(){sidebarCatalog=true;}
    private Runnable sidebarLocate=()->{},sidebarRefresh=()->{};
    private SidebarToolButton sidebarReload,sidebarSelection;
    private boolean libraryScanning;
    private LibraryLoadingView libraryEmpty;
    private String scanMessage="正在扫描音乐库…";
    void scanProgress(String message){scanMessage=message;updateLibraryEmpty();}
    private void updateLibraryEmpty(){if(libraryEmpty==null)return;libraryEmpty.palette(colors);libraryEmpty.state(libraryScanning,libraryScanning?scanMessage:section.equals("收藏")?"暂无收藏\n点按歌曲旁的爱心添加":section.equals("最近播放")?"还没有播放记录":pageKey.startsWith("歌单:")?"歌单还没有歌曲\n可从歌曲菜单或多选工具栏添加":"暂无歌曲\n可在设置中添加音乐文件夹");}
    void setScanning(boolean value){libraryScanning=value;if(sidebarReload!=null)sidebarReload.busy(value);updateHeading();updateLibraryEmpty();}
    private void jumpToSong(int index){list.smoothScrollBy(0,0);list.setSelectionFromTop(index,dp(8));}
    boolean focusCurrentSong(){if(current==null||list==null)return false;for(int i=0;i<songs.size();i++)if(songs.get(i).id==current.id){jumpToSong(i);return true;}return false;}
    void setSidebarTools(Runnable locate,Runnable refresh){sidebarLocate=locate;sidebarRefresh=refresh;}
    void refreshVisibleArtwork(){post(()->adapter.notifyDataSetChanged());}
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
    private final CoverAtmosphere atmosphere=new CoverAtmosphere();
    private PlayerStylePage glassSource;
    private GlassBackdrop workspaceGlass;
    void glassSource(PlayerStylePage value){glassSource=value;}
    void drawBackdrop(Canvas canvas){if(getBackground()!=null)getBackground().draw(canvas);}
    private final android.view.ViewTreeObserver.OnScrollChangedListener glassScroll=()->{if(isShown())refreshGlass();};
    private void refreshGlass(){if(workspaceGlass!=null)workspaceGlass.invalidateSnapshot();}
    @Override public void invalidateDrawable(android.graphics.drawable.Drawable drawable){super.invalidateDrawable(drawable);if(drawable==atmosphere)refreshGlass();}
    android.graphics.drawable.Drawable glassSurface(View host,float radius,boolean dark){if(glassSource!=null)return glassSource.glassSurface(host,radius,dark);if(workspaceGlass==null)workspaceGlass=new GlassBackdrop(this,true,18);return workspaceGlass.surface(host,radius,false,!dark);}

    private TextView album;
    private AbsListView list;private TextView listHeading,title,artist,nowPlaying;private ImageView cover;
    private LinearLayout libraryRoot,detailRoot,hero;private FrameLayout lyricPanel,heroSlot;private NativeLyricsView lyricView;
    private boolean lyricsExpanded;
    private ImageView lyricsExpandButton;
    private int position,duration,insetLeft,insetTop,insetRight,insetBottom,renderWidth,renderHeight,heroExtent;
    private String lyricStatus="暂无歌词";private ValueAnimator heroMotion;private int transitionEpoch,artGeneration;
    private final Map<String,Parcelable> scrollStates=new HashMap<>();
    private final Set<String> pending=new HashSet<>();
    private ThreadPoolExecutor images,detailImages;
    private final BaseAdapter adapter=new BaseAdapter(){
        public int getCount(){return songs.size();}public Song getItem(int index){return songs.get(index);}public long getItemId(int index){return getItem(index).id;}
        public View getView(int index,View recycled,ViewGroup parent){
            LinearLayout row;ImageView image;TextView caption,subtitle;LibraryActionButton star,more;
            if(recycled==null){
                row=new LinearLayout(getContext());row.setOutlineProvider(new ViewOutlineProvider(){@Override public void getOutline(View view,android.graphics.Outline outline){outline.setRoundRect(0,0,view.getWidth(),view.getHeight(),dp(12));}});row.setClipToOutline(true);row.setDescendantFocusability(FOCUS_BLOCK_DESCENDANTS);row.setOrientation(grouped?LinearLayout.VERTICAL:LinearLayout.HORIZONTAL);row.setGravity(Gravity.CENTER_VERTICAL);row.setPadding(dp(sidebarCatalog?8:12),dp(8),dp(sidebarCatalog?8:12),dp(8));
                image=grouped?new SquareArtwork(getContext()):new ImageView(getContext());image.setScaleType(ImageView.ScaleType.CENTER_CROP);image.setBackground(shape(colors.line,12));image.setClipToOutline(true);row.addView(image,new LinearLayout.LayoutParams(grouped?-1:dp(sidebarCatalog?52:46),grouped?-2:dp(sidebarCatalog?52:46)));
                LinearLayout labels=new LinearLayout(getContext());labels.setOrientation(LinearLayout.VERTICAL);labels.setPadding(grouped?0:dp(12),grouped?dp(10):0,dp(6),0);row.addView(labels,grouped?new LinearLayout.LayoutParams(-1,-2):new LinearLayout.LayoutParams(0,-2,1));
                caption=text("",sidebarCatalog?17:15,colors.text);caption.setTypeface(null,sidebarCatalog?Typeface.NORMAL:Typeface.BOLD);caption.setSingleLine(true);caption.setEllipsize(android.text.TextUtils.TruncateAt.END);
                subtitle=text("",12,colors.secondary);subtitle.setSingleLine(true);subtitle.setEllipsize(android.text.TextUtils.TruncateAt.END);subtitle.setPadding(0,dp(4),0,0);labels.addView(caption);labels.addView(subtitle);
                TextView artistCell=text("",13,colors.secondary),albumCell=text("",13,colors.secondary);artistCell.setSingleLine(true);albumCell.setSingleLine(true);artistCell.setEllipsize(android.text.TextUtils.TruncateAt.END);albumCell.setEllipsize(android.text.TextUtils.TruncateAt.END);
                if(!grouped){row.addView(artistCell,new LinearLayout.LayoutParams(columns.artist,dp(48)));row.addView(albumCell,new LinearLayout.LayoutParams(columns.album,dp(48)));}artistCell.setGravity(Gravity.CENTER_VERTICAL);albumCell.setGravity(Gravity.CENTER_VERTICAL);
                star=new LibraryActionButton(getContext(),true,colors.accent);more=new LibraryActionButton(getContext(),false,colors.secondary);if(!grouped){row.addView(star,new LinearLayout.LayoutParams(dp(40),dp(48)));}
                CheckBox check=new CheckBox(getContext());check.setButtonTintList(android.content.res.ColorStateList.valueOf(colors.accent));check.setContentDescription("选择歌曲");if(!grouped)row.addView(check,0,new LinearLayout.LayoutParams(dp(40),dp(48)));
                TextView length=text("",11,colors.secondary);length.setGravity(Gravity.CENTER);if(!grouped)row.addView(length,row.indexOfChild(star),new LinearLayout.LayoutParams(dp(42),dp(48)));
                SidebarPlaybackIndicator indicator=new SidebarPlaybackIndicator(getContext());if(sidebarCatalog)row.addView(indicator,new LinearLayout.LayoutParams(dp(30),dp(48)));
                row.setTag(new Object[]{image,caption,subtitle,star,more,check,length,artistCell,albumCell,indicator});
            }else row=(LinearLayout)recycled;
            Object[] holder=(Object[])row.getTag();image=(ImageView)holder[0];caption=(TextView)holder[1];subtitle=(TextView)holder[2];star=(LibraryActionButton)holder[3];more=(LibraryActionButton)holder[4];Song song=getItem(index);
            TextView artistCell=(TextView)holder[7],albumCell=(TextView)holder[8];artistCell.setText(song.artist);albumCell.setText(song.album);artistCell.setTextColor(colors.secondary);albumCell.setTextColor(colors.secondary);subtitle.setVisibility(!grouped&&columns.artist>0&&columns.album>0?GONE:VISIBLE);
            CheckBox check=(CheckBox)holder[5];check.setOnCheckedChangeListener(null);check.setVisibility(selecting?VISIBLE:GONE);check.setChecked(selection.contains(song.id));check.setContentDescription("选择 "+song.title);check.setOnCheckedChangeListener((button,value)->toggleSelection(song.id));
            TextView length=(TextView)holder[6];length.setText(String.format(java.util.Locale.ROOT,"%d:%02d",song.duration/60000,(song.duration/1000)%60));length.setVisibility(grouped||selecting?GONE:VISIBLE);
            star.setVisibility(selecting||sidebarCatalog?GONE:VISIBLE);more.setVisibility(GONE);
            if(sidebarCatalog){length.setVisibility(GONE);row.setMinimumHeight(dp(76));SidebarPlaybackIndicator indicator=(SidebarPlaybackIndicator)holder[9];boolean active=current!=null&&current.id==song.id;indicator.state(active,playing,colors.accent,selecting);}
            bindImage(image,song,grouped?512:256);caption.setText(song.title);subtitle.setText(grouped?song.groupCount+" 首歌曲":sidebarCatalog?song.artist:(columns.artist>0?song.album:song.artist+" · "+song.album));caption.setTextColor(current!=null&&current.id==song.id&&!grouped&&!sidebarCatalog?colors.accent:colors.text);subtitle.setTextColor(colors.secondary);
            boolean highlighted=!grouped&&(selecting?selection.contains(song.id):current!=null&&current.id==song.id);
            row.setBackground(highlighted?new android.graphics.drawable.LayerDrawable(new android.graphics.drawable.Drawable[]{glassSurface(row,12,colors.dark),shape(colors.dark?0x244FCDA6:0x180A8763,12)}):null);
            boolean saved=favorites.contains(Long.toString(song.id));star.state(saved,saved?colors.accent:colors.secondary);star.setContentDescription((saved?"取消收藏 ":"收藏 ")+song.title);more.state(false,colors.secondary);star.setOnClickListener(v->{if(favorite!=null)favorite.accept(song);});more.setContentDescription("编辑／歌曲操作："+song.title);more.setOnClickListener(v->{if(songMenu!=null)songMenu.accept(song);});return row;
        }
    };
    PlayerStylePage(Context context,Consumer<Song> play,IntConsumer seek,Runnable lyricsAction,Runnable browse){super(context);this.play=play;this.seek=seek;this.lyricsAction=lyricsAction;this.browse=browse;setVisibility(GONE);}
    private int dp(float value){return Math.round(value*getResources().getDisplayMetrics().density);}
    private TextView text(String value,int size,int color){TextView view=new TextView(getContext());view.setText(value);view.setTextSize(size);view.setTextColor(color);return view;}
    private GradientDrawable shape(int color,int radius){GradientDrawable shape=new GradientDrawable();shape.setColor(color);shape.setCornerRadius(dp(radius));return shape;}
    private TextView tool(String caption,Runnable action){TextView view=text(caption,16,colors.accent);view.setGravity(Gravity.CENTER);view.setMinHeight(dp(44));view.setPadding(dp(8),0,dp(8),0);view.setOnClickListener(v->action.run());ButtonFeedback.install(view);return view;}
    void setSongMenu(Consumer<Song> value){songMenu=value;}
    void setTools(Runnable back,Runnable options,Runnable queue,Consumer<Song> favorite){this.back=back;this.options=options;this.queue=queue;this.favorite=favorite;}
    void setFavorites(Set<String> value){if(favorites.equals(value))return;favorites=new HashSet<>(value);adapter.notifyDataSetChanged();updateSelection();updateLandscapeControls();}
    void configure(String value,AppAppearance.Palette palette){
        boolean changed=!style.equals(value),themeChanged=colors.dark!=palette.dark;saveScroll();style=value;colors=palette;
        if(changed){lyricsExpanded=false;expanded=false;catalogOpen=false;selecting=false;selection.clear();}if(usesCoverAtmosphere()){atmosphere.theme(colors.dark);setBackground(atmosphere);}else setBackgroundColor(sidebarCatalog?Color.TRANSPARENT:colors.background);
        setVisibility(style.equals("wall")?GONE:VISIBLE);
        if(style.equals("wall")){artGeneration++;pending.clear();if(images!=null)images.getQueue().clear();if(detailImages!=null)detailImages.getQueue().clear();}
        if(!style.equals("wall")&&(changed||themeChanged||getChildCount()==0)){render();if(changed)enter(this,14);}
    }
    private boolean inputOccludes;private int inputBottom;
    void setInputInsets(boolean occludes,int bottom){inputOccludes=occludes;inputBottom=bottom;}
    void setInsets(int left,int top,int right,int bottom){insetLeft=left;insetTop=top;insetRight=right;insetBottom=bottom;boolean footerWide=(getWidth()>0?getWidth():getResources().getDisplayMetrics().widthPixels)-left-right>=dp(620);setPadding(left,top+dp(landscapePlayback()||landscapeLibrary()?CONTENT_GAP:6+WallToolStyle.SIDE+CONTENT_GAP),right,inputOccludes?Math.max(bottom,inputBottom)+dp(CONTENT_GAP):bottom+dp(landscapePlayback()?CONTENT_GAP:8+(footerWide?88:104)+CONTENT_GAP));}
    void setSongs(List<Song> value){boolean nextGrouped=!value.isEmpty()&&value.get(0).groupCount>0;boolean layoutChanged=nextGrouped!=grouped;boolean same=value.size()==songs.size();if(same)for(int i=0;i<value.size();i++)if(value.get(i)!=songs.get(i)){same=false;break;}if(same&&!layoutChanged){updateHeading();return;}grouped=nextGrouped;if(grouped){selecting=false;selection.clear();}songs=new ArrayList<>(value);selection.retain(visibleIDs());if(layoutChanged&&!style.equals("wall"))render();else adapter.notifyDataSetChanged();updateHeading();updateSelection();}
    void setSection(String value){section=value.equals("歌曲")?"音乐库":value.startsWith("歌单:")?value.substring(3):value;updateHeading();}
    void preparePage(String key){if(pageKey.equals(key))return;saveScroll();selecting=false;selection.clear();if(!key.equals(groupParentKey)&&!key.equals(groupChildKey))clearGroupTransition();pageKey=key;int split=key.indexOf('\n');group=split<0||split==key.length()-1?null:key.substring(split+1);navigationPending=true;}
    void setBrowseContext(String group,String section){
        String key=section+"\n"+(group==null?"":group);boolean returningToCard=group==null&&key.equals(groupParentKey)&&groupSnapshot!=null;boolean changed=navigationPending||!pageKey.equals(key);navigationPending=false;if(!pageKey.equals(key))saveScroll();pageKey=key;this.group=group;setSection(group==null?section:group);
        if(changed&&!style.equals("wall")){if(style.equals("library"))expanded=false;render();if(libraryRoot!=null&&libraryRoot.getVisibility()==VISIBLE){if(group!=null&&pageKey.equals(groupChildKey)&&groupSnapshot!=null)openGroupTransition();else if(!returningToCard)enter(libraryRoot,group==null?-18:18);}if(group==null)clearGroupTransition();}
    }
    void setSong(Song song){boolean changed=current!=song&&(current==null||song==null||current.id!=song.id||!Objects.equals(current.artworkVersion,song.artworkVersion));current=song;if(changed){lyrics=Collections.emptyList();lyricStatus="正在加载歌词…";if(lyricView!=null){lyricView.lyrics(lyrics);lyricView.status(lyricStatus);}updateDetails();adapter.notifyDataSetChanged();}}
    void setLyricsStatus(String value){lyricStatus=value;if(lyricView!=null)lyricView.status(value);}
    void setLyrics(List<Lyrics.Line> value){lyrics=value;if(lyricView!=null)lyricView.lyrics(value);}
    void setPosition(int value){setPlayback(value,duration,playing);}
    void setPlayback(int value,int duration,boolean playing){if(sidebarCatalog&&this.playing!=playing)post(()->adapter.notifyDataSetChanged());position=value;this.duration=duration;this.playing=playing;updateLandscapeControls();if(lyricView!=null)lyricView.playback(value,duration,playing);}
    void locate(long id){if(style.equals("library")&&expanded)setExpanded(false);if(list!=null)for(int i=0;i<songs.size();i++)if(songs.get(i).id==id){jumpToSong(i);break;}}
    boolean collapse(){if(lyricsExpanded){toggleLyricsExpanded();return true;}if(selecting){setSelecting(false);return true;}if(group!=null&&(style.equals("library")&&!expanded||style.equals("simple")&&catalogOpen)){closeGroupTransition();return true;}if(style.equals("simple")&&catalogOpen){showPlayer();return true;}if(!expanded)return false;setExpanded(false);return true;}
    void showCatalog(){if(!style.equals("simple")||catalogOpen)return;catalogOpen=true;detailChanged.run();if(libraryRoot!=null){detailRoot.setVisibility(GONE);libraryRoot.setVisibility(VISIBLE);enter(libraryRoot,18);}}
    void showPlayer(){if(!style.equals("simple"))return;catalogOpen=false;detailChanged.run();if(detailRoot!=null){libraryRoot.setVisibility(GONE);detailRoot.setVisibility(VISIBLE);enter(detailRoot,-14);updateDetails();}}
    private Runnable detailChanged=()->{};
    void setDetailChanged(Runnable action){detailChanged=action;}
    boolean libraryDetailOpen(){return style.equals("library")&&expanded;}
    void toggleExpanded(){if(current!=null)setExpanded(!expanded);}
    private void updateHeading(){
        if(listHeading!=null)listHeading.setText(sidebarCatalog?(section.equals("最近播放")?"最近播放":"音乐库"):section);
        if(summary!=null)summary.setText(libraryScanning?"正在扫描…":String.format(java.util.Locale.getDefault(),"%,d %s",songs.size(),grouped?"项":"首"));
    }
    private List<Long> visibleIDs(){List<Long> ids=new ArrayList<>();for(Song song:songs)if(song.groupCount==0)ids.add(song.id);return ids;}
    private List<Song> selectedSongs(){List<Song> result=new ArrayList<>();for(Song song:songs)if(selection.contains(song.id))result.add(song);return result;}
    private boolean allFavorite(){List<Song> selected=selectedSongs();if(selected.isEmpty())return false;for(Song song:selected)if(!favorites.contains(Long.toString(song.id)))return false;return true;}
    private void toggleSelection(long id){selection.toggle(id);adapter.notifyDataSetChanged();updateSelection();}
    private void updateSelection(){
        if(selectionCount==null)return;selectionCount.setText("已选 "+selection.size()+" 首");selectionAll.setText(selection.all(visibleIDs())?"取消全选":"全选");selectionFavorite.setText(allFavorite()?"取消收藏":"收藏");boolean enabled=selection.size()>0;
        for(TextView item:new TextView[]{selectionFavorite,selectionPlaylist,selectionRemove}){item.setEnabled(enabled);item.setAlpha(enabled?1:.4f);}
        if(selectionToggle!=null)selectionToggle.setText(selecting?"完成":"多选");if(sidebarSelection!=null)sidebarSelection.selecting(selecting);refreshColumnHeader();
    }
    private void refreshColumnHeader(){
        if(columnHeader==null)return;columnHeader.removeAllViews();View leading=new View(getContext());columnHeader.addView(leading,new LinearLayout.LayoutParams(dp(58+(selecting?40:0)),1));
        column("歌曲","title",0,1);column("歌手","artist",columns.artist,0);if(columns.album>0)column("专辑","album",columns.album,0);
        if(!selecting){column("时长","duration",dp(42),0);TextView saved=text("收藏",11,colors.secondary);saved.setGravity(Gravity.CENTER);columnHeader.addView(saved,new LinearLayout.LayoutParams(dp(40),-1));}
    }
    private void column(String caption,String field,int width,float weight){
        TextView view=text(caption+(field.equals(sortField)?sortAscending?" ↑":" ↓":""),12,field.equals(sortField)?colors.accent:colors.secondary);view.setGravity(Gravity.CENTER_VERTICAL);columnHeader.addView(view,new LinearLayout.LayoutParams(width,-1,weight));view.setEnabled(sort!=null&&sortField!=null);view.setOnClickListener(v->{if(sort!=null)sort.accept(field,field.equals(sortField)?!sortAscending:true);});ButtonFeedback.install(view);
    }
    private android.graphics.drawable.Drawable selectionBackground(){
        android.graphics.drawable.GradientDrawable background=new android.graphics.drawable.GradientDrawable();
        background.setColor(colors.dark?0x244FCDA6:0x180A8763);
        background.setCornerRadius(dp(12));
        background.setStroke(dp(1),colors.dark?0x335FCDA8:0x22708179);
        return background;
    }
    private void setSelecting(boolean value){
        if(grouped||selecting==value)return;selecting=value;if(!value)selection.clear();adapter.notifyDataSetChanged();updateSelection();
        if(selectionBar==null)return;if(selectionMotion!=null)selectionMotion.cancel();selectionBar.setVisibility(VISIBLE);android.view.ViewGroup.LayoutParams params=selectionBar.getLayoutParams();int start=Math.max(0,params.height),end=value?dp(48):0;
        selectionMotion=ValueAnimator.ofInt(start,end);selectionMotion.setDuration(animations()?200:0);selectionMotion.addUpdateListener(a->{int height=(int)a.getAnimatedValue();params.height=height;selectionBar.setLayoutParams(params);selectionBar.setAlpha(height/(float)dp(48));});selectionMotion.addListener(new AnimatorListenerAdapter(){@Override public void onAnimationEnd(Animator animator){if(!selecting)selectionBar.setVisibility(GONE);}});selectionMotion.start();
    }
    private static final class SquareArtwork extends ImageView {
        SquareArtwork(Context context){super(context);}
        @Override protected void onMeasure(int widthSpec,int heightSpec){
            int side=MeasureSpec.getSize(widthSpec);
            super.onMeasure(MeasureSpec.makeMeasureSpec(side,MeasureSpec.EXACTLY),MeasureSpec.makeMeasureSpec(side,MeasureSpec.EXACTLY));
        }
    }
    private void captureGroup(View card,String name){
        clearGroupTransition();if(!animations()||libraryRoot==null||libraryRoot.getWidth()==0||libraryRoot.getHeight()==0)return;
        int[] origin=new int[2],base=new int[2];card.getLocationInWindow(origin);libraryRoot.getLocationInWindow(base);
        groupOrigin=new RectF(origin[0]-base[0],origin[1]-base[1],origin[0]-base[0]+card.getWidth(),origin[1]-base[1]+card.getHeight());
        groupParentKey=pageKey;groupChildKey=pageKey+name;Picture picture=new Picture();try{Canvas recording=picture.beginRecording(libraryRoot.getWidth(),libraryRoot.getHeight());try{libraryRoot.draw(recording);}finally{picture.endRecording();}groupSnapshot=picture;}catch(RuntimeException|OutOfMemoryError unavailable){clearGroupTransition();}
    }
    private View addGroupBackdrop(){
        final Picture picture=groupSnapshot;View backdrop=new View(getContext()){@Override protected void onDraw(Canvas canvas){super.onDraw(canvas);if(picture!=null)canvas.drawPicture(picture,new Rect(0,0,getWidth(),getHeight()));}};
        LayoutParams bounds=new LayoutParams(libraryRoot.getWidth(),libraryRoot.getHeight());bounds.leftMargin=libraryRoot.getLeft();bounds.topMargin=libraryRoot.getTop();addView(backdrop,0,bounds);return backdrop;
    }
    private void openGroupTransition(){
        final int epoch=transitionEpoch;final LinearLayout panel=libraryRoot;final RectF origin=new RectF(groupOrigin);final View backdrop=addGroupBackdrop();panel.setClickable(true);panel.setBackground(frostedPanel());panel.setClipToOutline(true);panel.setAlpha(0);
        panel.post(()->{if(epoch!=transitionEpoch||groupSnapshot==null)return;panel.animate().cancel();panel.setPivotX(0);panel.setPivotY(0);panel.setTranslationX(origin.left);panel.setTranslationY(origin.top);panel.setScaleX(origin.width()/Math.max(1,panel.getWidth()));panel.setScaleY(origin.height()/Math.max(1,panel.getHeight()));panel.setAlpha(1);panel.animate().translationX(0).translationY(0).scaleX(1).scaleY(1).alpha(1).setDuration(360).setInterpolator(new android.view.animation.DecelerateInterpolator()).withEndAction(()->{if(epoch==transitionEpoch)removeView(backdrop);}).start();});
    }
    private void closeGroupTransition(){
        if(closingGroup)return;if(groupSnapshot==null||groupOrigin==null||!animations()||libraryRoot==null){back.run();return;}
        closingGroup=true;int epoch=++transitionEpoch;libraryRoot.animate().cancel();addGroupBackdrop();libraryRoot.setBackground(frostedPanel());libraryRoot.setClipToOutline(true);libraryRoot.setPivotX(0);libraryRoot.setPivotY(0);libraryRoot.animate().translationX(groupOrigin.left).translationY(groupOrigin.top).scaleX(groupOrigin.width()/Math.max(1,libraryRoot.getWidth())).scaleY(groupOrigin.height()/Math.max(1,libraryRoot.getHeight())).alpha(1).setDuration(320).setInterpolator(new android.view.animation.AccelerateDecelerateInterpolator()).withEndAction(()->{if(epoch==transitionEpoch){closingGroup=false;back.run();}}).start();
    }
    private void clearGroupTransition(){groupSnapshot=null;groupOrigin=null;groupParentKey=null;groupChildKey=null;}
    private void saveScroll(){if(list!=null)scrollStates.put(pageKey,list.onSaveInstanceState());}
    private void enter(View view,float shift){view.animate().cancel();if(!animations()){view.setAlpha(1);view.setTranslationY(0);return;}view.setAlpha(0);view.setTranslationY(dp(shift));view.animate().alpha(1).translationY(0).setDuration(280).setInterpolator(new android.view.animation.DecelerateInterpolator()).start();}
    private boolean snapshotTransition;
    void setSnapshotTransition(boolean value){snapshotTransition=value;}
    private boolean animations(){return !snapshotTransition&&ValueAnimator.areAnimatorsEnabled();}
    private void render(){
        transitionEpoch++;closingGroup=false;if(libraryRoot!=null)libraryRoot.animate().cancel();if(heroMotion!=null){heroMotion.cancel();heroMotion=null;}if(selectionMotion!=null){selectionMotion.removeAllListeners();selectionMotion.cancel();selectionMotion=null;}animate().cancel();setAlpha(1);setTranslationY(0);removeAllViews();artGeneration++;pending.clear();if(images!=null)images.getQueue().clear();if(detailImages!=null)detailImages.getQueue().clear();
        lyricsExpandButton=null;libraryEmpty=null;sidebarReload=null;sidebarSelection=null;album=null;list=null;listHeading=null;selectionBar=null;selectionCount=null;selectionToggle=null;summary=null;columnHeader=null;cover=null;title=null;artist=null;nowPlaying=null;lyricView=null;hero=null;libraryRoot=null;detailRoot=null;
        if(style.equals("wall"))return;
        wide=getWidth()-getPaddingLeft()-getPaddingRight()>dp(620);columns=new LibraryColumns(getWidth()-getPaddingLeft()-getPaddingRight(),getResources().getDisplayMetrics().density);
        buildLibrary();if(sidebarCatalog){updateHeading();return;}buildDetails();
        boolean showingDetail=style.equals("simple")?!catalogOpen:expanded;
        detailRoot.setVisibility(showingDetail?VISIBLE:GONE);libraryRoot.setVisibility(showingDetail?GONE:VISIBLE);
        updateDetails();updateHeading();detailChanged.run();
    }
    private SidebarToolButton sidebarTool(int kind,String label,Runnable action){return new SidebarToolButton(getContext(),kind,colors.accent,label,action);}
    private void buildLibrary(){
        libraryRoot=new LinearLayout(getContext());libraryRoot.setOrientation(LinearLayout.VERTICAL);if(group!=null){libraryRoot.setBackground(frostedPanel());libraryRoot.setClipToOutline(true);}addView(libraryRoot,new LayoutParams(-1,-1));
        if(sidebarCatalog||style.equals("library")){
            LinearLayout toolbar=new LinearLayout(getContext());toolbar.setGravity(Gravity.CENTER_VERTICAL);toolbar.setPadding(dp(sidebarCatalog?0:20),0,dp(sidebarCatalog?0:4),dp(4));libraryRoot.addView(toolbar,new LinearLayout.LayoutParams(-1,-2));
            if(group!=null&&!sidebarCatalog)toolbar.addView(new PageBackButton(getContext(),colors.accent,this::closeGroupTransition),new LinearLayout.LayoutParams(dp(40),dp(44)));
            LinearLayout labels=new LinearLayout(getContext());labels.setOrientation(LinearLayout.HORIZONTAL);labels.setGravity(Gravity.CENTER_VERTICAL);toolbar.addView(labels,new LinearLayout.LayoutParams(0,dp(44),1));
            listHeading=text("",14,colors.text);listHeading.setTypeface(null,Typeface.BOLD);listHeading.setIncludeFontPadding(false);listHeading.setSingleLine(true);listHeading.setEllipsize(android.text.TextUtils.TruncateAt.END);labels.addView(listHeading,new LinearLayout.LayoutParams(-2,-2));
            summary=text("",12,colors.secondary);summary.setIncludeFontPadding(false);summary.setSingleLine(true);summary.setEllipsize(android.text.TextUtils.TruncateAt.END);summary.setPadding(dp(8),0,0,0);labels.addView(summary,new LinearLayout.LayoutParams(0,-2,1));
            toolbar.addView(sidebarTool(SidebarToolButton.LOCATE,"定位正在播放的歌曲",sidebarLocate),new LinearLayout.LayoutParams(dp(44),dp(44)));
            sidebarReload=sidebarTool(SidebarToolButton.RELOAD,"重新扫描音乐库",sidebarRefresh);sidebarReload.busy(libraryScanning);toolbar.addView(sidebarReload,new LinearLayout.LayoutParams(dp(44),dp(44)));
            toolbar.addView(sidebarTool(SidebarToolButton.SORT,"歌曲排序",options),new LinearLayout.LayoutParams(dp(44),dp(44)));
            sidebarSelection=sidebarTool(SidebarToolButton.SELECT,"多选歌曲",()->setSelecting(!selecting));sidebarSelection.selecting(selecting);toolbar.addView(sidebarSelection,new LinearLayout.LayoutParams(dp(44),dp(44)));sidebarSelection.setVisibility(grouped?GONE:VISIBLE);
            View divider=new View(getContext());divider.setBackgroundColor(colors.dark?0x337E9690:0x33708179);libraryRoot.addView(divider,new LinearLayout.LayoutParams(-1,dp(1)));
        }else{
        LinearLayout toolbar=new LinearLayout(getContext());toolbar.setGravity(Gravity.CENTER_VERTICAL);toolbar.setPadding(dp(12),dp(4),dp(8),dp(8));libraryRoot.addView(toolbar);
        if(group!=null||style.equals("simple")){PageBackButton arrow=new PageBackButton(getContext(),colors.accent,group!=null?this::closeGroupTransition:this::showPlayer);toolbar.addView(arrow,new LinearLayout.LayoutParams(dp(44),dp(44)));}
        listHeading=text("",22,colors.text);listHeading.setSingleLine(true);listHeading.setEllipsize(android.text.TextUtils.TruncateAt.END);listHeading.setTypeface(null,Typeface.BOLD);toolbar.addView(listHeading,new LinearLayout.LayoutParams(-2,-2));
        summary=text("",12,colors.secondary);summary.setPadding(dp(10),0,0,0);summary.setSingleLine(true);toolbar.addView(summary,new LinearLayout.LayoutParams(0,-2,1));
        }
        selectionBar=new HorizontalScrollView(getContext());selectionBar.setHorizontalScrollBarEnabled(false);selectionBar.setFillViewport(true);selectionBar.setBackground(selectionBackground());libraryRoot.addView(selectionBar,new LinearLayout.LayoutParams(-1,selecting?dp(48):0));selectionBar.setVisibility(selecting?VISIBLE:GONE);
        LinearLayout batchRow=new LinearLayout(getContext());batchRow.setGravity(Gravity.CENTER_VERTICAL);batchRow.setPadding(dp(12),0,dp(12),0);selectionBar.addView(batchRow,new HorizontalScrollView.LayoutParams(-2,dp(48)));
        selectionCount=text("",13,colors.secondary);batchRow.addView(selectionCount,new LinearLayout.LayoutParams(0,-2,1));selectionAll=tool("全选",()->{selection.toggleAll(visibleIDs());adapter.notifyDataSetChanged();updateSelection();});selectionFavorite=tool("收藏",()->{if(batch!=null)batch.favorite(selectedSongs(),!allFavorite());});selectionPlaylist=tool("加入歌单",()->{if(batch!=null)batch.playlist(selectedSongs());});selectionRemove=tool("从歌单移除",()->{if(batch!=null)batch.removeFromPlaylist(selectedSongs());});
        batchRow.addView(selectionAll);batchRow.addView(selectionFavorite);batchRow.addView(selectionPlaylist);if(pageKey.startsWith("歌单:"))batchRow.addView(selectionRemove);updateSelection();
        nowPlaying=tool("",()->{if(style.equals("simple"))showPlayer();else toggleExpanded();});nowPlaying.setSingleLine(true);nowPlaying.setEllipsize(android.text.TextUtils.TruncateAt.END);nowPlaying.setGravity(Gravity.START|Gravity.CENTER_VERTICAL);nowPlaying.setPadding(dp(20),0,dp(20),0);nowPlaying.setBackground(shape(colors.surface,12));libraryRoot.addView(nowPlaying,new LinearLayout.LayoutParams(-1,dp(48)));
        // The persistent playback bar already provides this entry in landscape.
        if(sidebarCatalog||style.equals("simple")||style.equals("library")||getResources().getConfiguration().orientation==android.content.res.Configuration.ORIENTATION_LANDSCAPE)nowPlaying.setVisibility(GONE);
        if(!grouped&&columns.artist>0){columnHeader=new LinearLayout(getContext());columnHeader.setGravity(Gravity.CENTER_VERTICAL);columnHeader.setPadding(dp(20),0,dp(20),0);libraryRoot.addView(columnHeader,new LinearLayout.LayoutParams(-1,dp(32)));refreshColumnHeader();}
        FrameLayout results=new FrameLayout(getContext());libraryRoot.addView(results,new LinearLayout.LayoutParams(-1,0,1));
        if(grouped){GridView grid=new GridView(ListScrollStyle.context(getContext()));grid.setNumColumns(wide?3:2);grid.setHorizontalSpacing(dp(8));grid.setVerticalSpacing(dp(8));grid.setStretchMode(GridView.STRETCH_COLUMN_WIDTH);list=grid;}else{ListView tracks=new ListView(ListScrollStyle.context(getContext()));tracks.setDivider(null);list=tracks;}
        if(grouped)ListScrollStyle.fast(list);list.setSelector(shape(colors.dark?0x1851D5AA:0x140A8763,12));list.setCacheColorHint(0);list.setPadding(dp(sidebarCatalog?0:8),dp(8),dp(grouped?(sidebarCatalog?0:8):32),dp(16));list.setClipToPadding(false);list.setAdapter(adapter);results.addView(list,new LayoutParams(-1,-1));
        list.setOnItemClickListener((parent,view,index,id)->{if(selecting)toggleSelection(songs.get(index).id);else{if(grouped)captureGroup(view,songs.get(index).title);else if(view.getTag() instanceof Object[])songLaunch.accept((ImageView)((Object[])view.getTag())[0]);play.accept(songs.get(index));}});list.setOnItemLongClickListener((parent,view,index,id)->{Song song=songs.get(index);if(grouped||songMenu==null)return false;if(selecting)toggleSelection(song.id);else songMenu.accept(song);return true;});
        libraryEmpty=new LibraryLoadingView(getContext());updateLibraryEmpty();results.addView(libraryEmpty,new LayoutParams(-1,-1));list.setEmptyView(libraryEmpty);
        if(list instanceof ListView){ListScrollThumb thumb=new ListScrollThumb((ListView)list,colors.accent,busy->{});thumb.setContentDescription("拖动滚动歌曲列表");LayoutParams rail=new LayoutParams(dp(32),-1,Gravity.RIGHT);rail.topMargin=dp(12);rail.bottomMargin=dp(16);results.addView(thumb,rail);}
        Parcelable saved=scrollStates.get(pageKey);if(saved!=null)list.onRestoreInstanceState(saved);
    }
    private void buildDetails(){
        landscapeSeek=null;landscapePlay=null;landscapeMode=null;landscapeFavorite=null;
        if(landscapeLayout()){buildLandscapeDetails();return;}
        if(style.equals("simple")){buildSimpleDetails();return;}
        detailRoot=new LinearLayout(getContext());detailRoot.setOrientation(LinearLayout.VERTICAL);detailRoot.setPadding(dp(14),0,dp(14),0);detailRoot.setBackgroundColor(Color.TRANSPARENT);addView(detailRoot,new LayoutParams(-1,-1));
        LinearLayout workspace=new LinearLayout(getContext());workspace.setOrientation(wide?LinearLayout.HORIZONTAL:LinearLayout.VERTICAL);detailRoot.addView(workspace,new LinearLayout.LayoutParams(-1,0,1));
        hero=new LinearLayout(getContext());hero.setOrientation(LinearLayout.VERTICAL);hero.setGravity(Gravity.CENTER);hero.setPadding(dp(20),dp(8),dp(20),dp(8));
        int availableH=Math.max(1,getHeight()-getPaddingTop()-getPaddingBottom());
        PlayerWorkspaceMetrics metrics=new PlayerWorkspaceMetrics(Math.max(1,getWidth()-getPaddingLeft()-getPaddingRight()),availableH,getResources().getDisplayMetrics().density);
        int side=metrics.artwork;heroExtent=metrics.wide?metrics.hero:Math.min(metrics.hero,side+dp(80));
        boolean hidden=lyricsExpanded;
        heroSlot=new FrameLayout(getContext());ScrollView heroScroll=new ScrollView(getContext());heroScroll.setFillViewport(true);ListScrollStyle.apply(heroScroll);heroScroll.addView(hero,new ScrollView.LayoutParams(-1,-1));heroSlot.addView(heroScroll,new LayoutParams(-1,-1));
        workspace.addView(heroSlot,wide?new LinearLayout.LayoutParams(hidden?0:heroExtent,-1):new LinearLayout.LayoutParams(-1,hidden?0:heroExtent));hero.setAlpha(hidden?0:1);hero.setImportantForAccessibility(hidden?IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS:IMPORTANT_FOR_ACCESSIBILITY_AUTO);
        cover=new ImageView(getContext());cover.setScaleType(ImageView.ScaleType.CENTER_CROP);cover.setBackground(shape(colors.line,18));cover.setClipToOutline(true);cover.setContentDescription("展开或收起歌词");cover.setOnClickListener(v->toggleExpanded());ButtonFeedback.install(cover);hero.addView(cover,new LinearLayout.LayoutParams(side,side));
        title=text("",23,colors.text);title.setTypeface(null,Typeface.BOLD);title.setMaxLines(2);title.setEllipsize(android.text.TextUtils.TruncateAt.END);title.setGravity(Gravity.CENTER);title.setPadding(0,dp(12),0,0);hero.addView(title,new LinearLayout.LayoutParams(-1,-2));
        artist=text("",13,colors.secondary);artist.setGravity(Gravity.CENTER);artist.setMaxLines(2);artist.setEllipsize(android.text.TextUtils.TruncateAt.END);artist.setPadding(0,dp(6),0,0);hero.addView(artist,new LinearLayout.LayoutParams(-1,-2));
        lyricPanel=new FrameLayout(getContext());lyricPanel.setBackground(glassSurface(lyricPanel,20,colors.dark));lyricPanel.setClipToOutline(true);workspace.addView(lyricPanel,wide?new LinearLayout.LayoutParams(0,-1,1):new LinearLayout.LayoutParams(-1,0,1));
        lyricView=new NativeLyricsView(getContext(),seek,lyricsAction);lyricView.palette(colors);lyricView.lyrics(lyrics);lyricView.status(lyricStatus);lyricView.playback(position,duration,playing);lyricPanel.addView(lyricView,new LayoutParams(-1,-1));
        installLyricsExpand(lyricPanel);
    }
    private void buildLandscapeDetails(){
        detailRoot=new LinearLayout(getContext());detailRoot.setOrientation(LinearLayout.HORIZONTAL);detailRoot.setPadding(dp(16),0,dp(16),0);addView(detailRoot,new LayoutParams(-1,-1));
        FrameLayout leftSlot=new FrameLayout(getContext());heroSlot=leftSlot;detailRoot.addView(leftSlot,new LinearLayout.LayoutParams(0,-1,1));leftSlot.setVisibility(lyricsExpanded?GONE:VISIBLE);
        int availableHeight=Math.max(dp(260),getHeight()-getPaddingTop()-getPaddingBottom());
        int availableWidth=Math.max(dp(160),Math.round((getWidth()-getPaddingLeft()-getPaddingRight()-dp(32))*.50f)-dp(24));
        int columnWidth=Math.min(availableWidth,Math.max(dp(140),availableHeight-dp(156)));
        LinearLayout left=new LinearLayout(getContext());left.setOrientation(LinearLayout.VERTICAL);
        FrameLayout.LayoutParams column=new FrameLayout.LayoutParams(columnWidth,-1,Gravity.CENTER_HORIZONTAL);leftSlot.addView(left,column);
        FrameLayout artworkSlot=new FrameLayout(getContext());left.addView(artworkSlot,new LinearLayout.LayoutParams(-1,0,1));
        cover=new ImageView(getContext());cover.setScaleType(ImageView.ScaleType.FIT_CENTER);cover.setBackground(shape(Color.TRANSPARENT,16));cover.setClipToOutline(true);artworkSlot.addView(cover,new LayoutParams(-1,-1));
        LinearLayout metadata=new LinearLayout(getContext());metadata.setGravity(Gravity.CENTER_VERTICAL);left.addView(metadata,new LinearLayout.LayoutParams(-1,-2));
        LinearLayout labels=new LinearLayout(getContext());labels.setOrientation(LinearLayout.VERTICAL);labels.setPadding(0,dp(8),dp(8),dp(4));metadata.addView(labels,new LinearLayout.LayoutParams(0,-2,1));
        title=text("",16,colors.text);title.setTypeface(null,Typeface.BOLD);title.setSingleLine(true);title.setEllipsize(android.text.TextUtils.TruncateAt.END);labels.addView(title);
        artist=text("",12,colors.secondary);artist.setSingleLine(true);artist.setEllipsize(android.text.TextUtils.TruncateAt.END);labels.addView(artist);
        album=text("",11,colors.secondary);album.setSingleLine(true);album.setEllipsize(android.text.TextUtils.TruncateAt.END);labels.addView(album);
        landscapeFavorite=new LibraryActionButton(getContext(),true,colors.accent);landscapeFavorite.setOnClickListener(v->{if(current!=null&&favorite!=null)favorite.accept(current);});metadata.addView(landscapeFavorite,new LinearLayout.LayoutParams(dp(44),dp(44)));
        LinearLayout progress=new LinearLayout(getContext());progress.setGravity(Gravity.CENTER_VERTICAL);left.addView(progress,new LinearLayout.LayoutParams(-1,dp(36)));
        landscapeTime=text("0:00",10,colors.secondary);landscapeTotal=text("0:00",10,colors.secondary);progress.addView(landscapeTime,new LinearLayout.LayoutParams(dp(36),-2));
        landscapeSeek=new SeekBar(getContext());landscapeSeek.setProgressBackgroundTintList(android.content.res.ColorStateList.valueOf(colors.dark?0x667A9690:0x66708179));landscapeSeek.setSplitTrack(false);landscapeSeek.setPadding(dp(8),0,dp(8),0);landscapeSeek.setProgressTintList(android.content.res.ColorStateList.valueOf(colors.accent));landscapeSeek.setThumbTintList(android.content.res.ColorStateList.valueOf(Color.WHITE));progress.addView(landscapeSeek,new LinearLayout.LayoutParams(0,-1,1));progress.addView(landscapeTotal,new LinearLayout.LayoutParams(dp(36),-2));
        landscapeSeek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){public void onProgressChanged(SeekBar bar,int value,boolean user){}public void onStartTrackingTouch(SeekBar bar){}public void onStopTrackingTouch(SeekBar bar){seek.accept(bar.getProgress());}});
        LinearLayout controls=new LinearLayout(getContext());controls.setGravity(Gravity.CENTER_VERTICAL);left.addView(controls,new LinearLayout.LayoutParams(-1,dp(56)));
        landscapeMode=tool("",()->{if(playbackActions!=null){playbackActions.selectPlaybackMode((PlaybackModes.valid(playbackActions.playbackMode())+1)%PlaybackModes.NAMES.length);updateLandscapeControls();}});controls.addView(landscapeMode,new LinearLayout.LayoutParams(0,-1,1));
        TransportButton previous=new TransportButton(getContext(),TransportButton.Glyph.PREVIOUS_TRACK,()->{if(playbackActions!=null)playbackActions.previous();});controls.addView(previous,new LinearLayout.LayoutParams(0,-1,1));
        landscapePlay=new TransportButton(getContext(),TransportButton.Glyph.PLAY_PAUSE,()->{if(playbackActions!=null)playbackActions.toggle();});landscapePlay.setBackground(shape(colors.accent,28));FrameLayout playSlot=new FrameLayout(getContext());controls.addView(playSlot,new LinearLayout.LayoutParams(0,-1,1));int playSize=Math.min(dp(56),columnWidth/5);playSlot.addView(landscapePlay,new FrameLayout.LayoutParams(playSize,playSize,Gravity.CENTER));
        TransportButton next=new TransportButton(getContext(),TransportButton.Glyph.NEXT_TRACK,()->{if(playbackActions!=null)playbackActions.next();});controls.addView(next,new LinearLayout.LayoutParams(0,-1,1));
        TransportButton queueButton=new TransportButton(getContext(),TransportButton.Glyph.QUEUE,queue);queueButton.setContentDescription("播放队列");controls.addView(queueButton,new LinearLayout.LayoutParams(0,-1,1));
        for(TransportButton button:new TransportButton[]{previous,next,queueButton})button.setColors(colors.text,colors.surface);landscapePlay.setColors(colors.text,Color.WHITE);
        FrameLayout rightSlot=new FrameLayout(getContext());rightSlot.setBackground(glassSurface(rightSlot,20,colors.dark));rightSlot.setClipToOutline(true);detailRoot.addView(rightSlot,new LinearLayout.LayoutParams(0,-1,1));
        lyricView=new NativeLyricsView(getContext(),seek,lyricsAction);lyricView.palette(colors);lyricView.lyrics(lyrics);lyricView.status(lyricStatus);lyricView.playback(position,duration,playing);
        rightSlot.addView(lyricView,new FrameLayout.LayoutParams(-1,-1));
        if(style.equals("library"))installLyricsExpand(rightSlot);
        updateLandscapeControls();
    }
    private void installLyricsExpand(FrameLayout panel){
        lyricView.reserveExpandControl(true);
        lyricsExpandButton=new ImageView(getContext());lyricsExpandButton.setScaleType(ImageView.ScaleType.CENTER);
        android.graphics.drawable.GradientDrawable mask=shape(Color.WHITE,22);
        lyricsExpandButton.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(colors.dark?0x22FFFFFF:0x180A8763),null,mask));
        lyricsExpandButton.setOnClickListener(v->toggleLyricsExpanded());ButtonFeedback.install(lyricsExpandButton);
        panel.addView(lyricsExpandButton,new LayoutParams(dp(44),dp(44),Gravity.TOP|Gravity.RIGHT));updateLyricsExpandIcon();
    }
    private void updateLyricsExpandIcon(){if(lyricsExpandButton!=null){lyricsExpandButton.setImageDrawable(new SimplePlayerGlyph(lyricsExpanded?SimplePlayerGlyph.COLLAPSE:SimplePlayerGlyph.EXPAND,colors.secondary,getResources().getDisplayMetrics().density));lyricsExpandButton.setContentDescription(lyricsExpanded?"收起歌词":"展开歌词");}}
    private void toggleLyricsExpanded(){
        if(!style.equals("library")||heroSlot==null)return;
        lyricsExpanded=!lyricsExpanded;updateLyricsExpandIcon();
        if(heroMotion!=null){heroMotion.cancel();heroMotion=null;}
        if(landscapeLayout()){heroSlot.setVisibility(lyricsExpanded?GONE:VISIBLE);return;}
        LinearLayout.LayoutParams params=(LinearLayout.LayoutParams)heroSlot.getLayoutParams();
        int start=wide?params.width:params.height,end=lyricsExpanded?0:heroExtent;
        hero.setImportantForAccessibility(lyricsExpanded?IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS:IMPORTANT_FOR_ACCESSIBILITY_AUTO);
        heroMotion=ValueAnimator.ofInt(start,end);heroMotion.setDuration(animations()?260:0);heroMotion.setInterpolator(new android.view.animation.DecelerateInterpolator());
        heroMotion.addUpdateListener(a->{int extent=(int)a.getAnimatedValue();if(wide)params.width=extent;else params.height=extent;heroSlot.setLayoutParams(params);hero.setAlpha(Math.min(1,extent/(float)Math.max(1,heroExtent)));});heroMotion.start();
    }
    private void updateLandscapeControls(){
        if(landscapePlay==null)return;landscapePlay.setPlaying(playing);landscapePlay.setEnabled(current!=null);
        if(!landscapeSeek.isPressed()){landscapeSeek.setMax(Math.max(1,duration));landscapeSeek.setProgress(position);}landscapeSeek.setEnabled(current!=null&&duration>0);
        landscapeTime.setText(String.format(java.util.Locale.ROOT,"%d:%02d",position/60000,position/1000%60));landscapeTotal.setText(String.format(java.util.Locale.ROOT,"%d:%02d",duration/60000,duration/1000%60));
        int mode=playbackActions==null?1:PlaybackModes.valid(playbackActions.playbackMode());PlaybackModeGlyph.bind(landscapeMode,mode,colors.accent);landscapeMode.setContentDescription("播放模式："+PlaybackModes.NAMES[mode]+"，点击切换");
        boolean saved=current!=null&&favorites.contains(Long.toString(current.id));landscapeFavorite.state(saved,saved?colors.accent:colors.secondary);landscapeFavorite.setEnabled(current!=null);landscapeFavorite.setContentDescription(saved?"取消收藏":"收藏歌曲");
    }
    private GradientDrawable frostedPanel(){return FrostedSurface.background(getContext(),20,colors.dark);}
    private void buildSimpleDetails(){
        detailRoot=new LinearLayout(getContext());detailRoot.setOrientation(wide?LinearLayout.HORIZONTAL:LinearLayout.VERTICAL);detailRoot.setPadding(dp(14),0,dp(14),0);addView(detailRoot,new LayoutParams(-1,-1));
        int availableH=Math.max(1,getHeight()-getPaddingTop()-getPaddingBottom());
        int availableW=Math.max(1,getWidth()-getPaddingLeft()-getPaddingRight()-dp(28));
        heroExtent=wide?availableW/2:Math.min(availableH/2,Math.round(availableW*.40f)+dp(CONTENT_GAP));
        heroSlot=new FrameLayout(getContext());detailRoot.addView(heroSlot,wide?new LinearLayout.LayoutParams(expanded?0:heroExtent,-1):new LinearLayout.LayoutParams(-1,expanded?0:heroExtent));
        hero=new LinearLayout(getContext());hero.setOrientation(wide?LinearLayout.VERTICAL:LinearLayout.HORIZONTAL);hero.setGravity(wide?Gravity.CENTER:Gravity.TOP);hero.setPadding(0,0,dp(wide?16:0),0);heroSlot.addView(hero,new LayoutParams(-1,-1));
        int side=wide?Math.max(1,Math.min(heroExtent-dp(32),availableH-dp(120))):Math.max(1,Math.min(Math.round(availableW*.40f),heroExtent-dp(CONTENT_GAP)));
        cover=new ImageView(getContext());cover.setScaleType(ImageView.ScaleType.CENTER_CROP);cover.setBackground(shape(colors.line,20));cover.setClipToOutline(true);cover.setContentDescription("展开或收起歌词");cover.setOnClickListener(v->toggleExpanded());ButtonFeedback.install(cover);hero.addView(cover,new LinearLayout.LayoutParams(side,side));
        LinearLayout info=new LinearLayout(getContext());info.setOrientation(LinearLayout.VERTICAL);info.setGravity(wide?Gravity.CENTER:Gravity.CENTER_VERTICAL);info.setPadding(dp(wide?0:22),dp(wide?10:0),0,0);hero.addView(info,wide?new LinearLayout.LayoutParams(-1,-2):new LinearLayout.LayoutParams(0,-2,1));
        title=text("",24,colors.text);title.setTypeface(null,Typeface.BOLD);title.setMaxLines(2);title.setEllipsize(android.text.TextUtils.TruncateAt.END);info.addView(title);
        artist=text("",16,colors.text);artist.setTypeface(null,Typeface.BOLD);artist.setSingleLine(true);artist.setEllipsize(android.text.TextUtils.TruncateAt.END);artist.setPadding(0,dp(6),0,0);info.addView(artist);
        album=text("",14,colors.secondary);album.setSingleLine(true);album.setEllipsize(android.text.TextUtils.TruncateAt.END);album.setPadding(0,dp(6),0,0);info.addView(album);
        lyricPanel=new FrameLayout(getContext());lyricPanel.setBackground(glassSurface(lyricPanel,20,colors.dark));lyricPanel.setClipToOutline(true);detailRoot.addView(lyricPanel,wide?new LinearLayout.LayoutParams(0,-1,1):new LinearLayout.LayoutParams(-1,0,1));
        lyricView=new NativeLyricsView(getContext(),seek,lyricsAction);lyricView.frosted(true);lyricView.palette(colors);lyricView.lyrics(lyrics);lyricView.status(lyricStatus);lyricView.playback(position,duration,playing);lyricPanel.addView(lyricView,new LayoutParams(-1,-1));
        ImageView expand=new ImageView(getContext());expand.setImageDrawable(new SimplePlayerGlyph(expanded?SimplePlayerGlyph.COLLAPSE:SimplePlayerGlyph.EXPAND,colors.secondary,getResources().getDisplayMetrics().density));expand.setScaleType(ImageView.ScaleType.CENTER);expand.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x22708179),null,null));expand.setOnClickListener(v->toggleExpanded());ButtonFeedback.install(expand);expand.setContentDescription(expanded?"收起歌词":"展开歌词");expand.setTag("expand");lyricPanel.addView(expand,new LayoutParams(dp(44),dp(44),Gravity.TOP|Gravity.RIGHT));
        if(current==null){title.setOnClickListener(v->browse.run());title.setContentDescription("选择歌曲，打开音乐库");}
    }
    private void updateDetails(){
        if(title!=null)title.setText(current==null?"选择一首歌曲":current.title);
        if(artist!=null)artist.setText(current==null?"从音乐库开始播放":style.equals("simple")?current.artist:current.artist+" · "+current.album);
        if(album!=null)album.setText(current==null?"MiniVoice":current.album);
        if(usesCoverAtmosphere())updateAtmosphere(current==null?null:current.artworkPreview);
        if(nowPlaying!=null){nowPlaying.setText(current==null?"选择一首歌曲开始播放":"正在播放 · "+current.title+"  ›");nowPlaying.setEnabled(current!=null);}
        if(cover!=null&&current!=null)bindImage(cover,current,1600);updateLandscapeControls();
    }
    private void setExpanded(boolean value){
        if(expanded==value||style.equals("wall"))return;if(!value&&lyricsExpanded)toggleLyricsExpanded();expanded=value;detailChanged.run();int epoch=++transitionEpoch;
        if(style.equals("library")){
            if(libraryRoot==null||detailRoot==null)return;View target=value?detailRoot:libraryRoot,source=value?libraryRoot:detailRoot;
            source.animate().cancel();target.animate().cancel();target.setVisibility(VISIBLE);if(value)updateDetails();target.setAlpha(animations()?0:1);target.setTranslationY(animations()?dp(value?28:-16):0);source.setEnabled(false);target.bringToFront();target.setClickable(true);
            if(!animations()){source.setVisibility(GONE);source.setEnabled(true);return;}
            source.animate().alpha(0).setDuration(180).withEndAction(()->{if(epoch==transitionEpoch){source.setVisibility(GONE);source.setEnabled(true);source.setAlpha(1);}}).start();
            target.setEnabled(true);target.animate().alpha(1).translationY(0).setDuration(320).setInterpolator(new android.view.animation.DecelerateInterpolator()).start();
        }else if(hero!=null){
            if(heroMotion!=null){heroMotion.cancel();heroMotion=null;}LinearLayout.LayoutParams params=(LinearLayout.LayoutParams)heroSlot.getLayoutParams();int start=wide?params.width:params.height,end=value?0:heroExtent;
            ImageView toggle=detailRoot.findViewWithTag("expand");if(toggle!=null){toggle.setImageDrawable(new SimplePlayerGlyph(value?SimplePlayerGlyph.COLLAPSE:SimplePlayerGlyph.EXPAND,colors.secondary,getResources().getDisplayMetrics().density));toggle.setContentDescription(value?"收起歌词":"展开歌词");}hero.setImportantForAccessibility(value?IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS:IMPORTANT_FOR_ACCESSIBILITY_AUTO);
            heroMotion=ValueAnimator.ofInt(start,end);heroMotion.setDuration(animations()?320:0);heroMotion.setInterpolator(new android.view.animation.DecelerateInterpolator());heroMotion.addUpdateListener(a->{int extent=(int)a.getAnimatedValue();if(wide)params.width=extent;else params.height=extent;heroSlot.setLayoutParams(params);hero.setAlpha(heroExtent==0?1:extent/(float)heroExtent);});heroMotion.start();
        }
    }
    private boolean usesCoverAtmosphere(){return !sidebarCatalog&&(style.equals("simple")||style.equals("library"));}
    private void updateAtmosphere(Bitmap bitmap){atmosphere.artwork(bitmap);if(workspaceGlass!=null)workspaceGlass.invalidateSnapshot();}
    private void bindImage(ImageView image,Song song,int side){
        String key=song.uri+"\n"+song.artworkUri+"\n"+song.artworkVersion+"\n"+side;image.setTag(key);Bitmap bitmap=ArtworkCache.peek(song,side);if(bitmap==null)bitmap=song.artworkPreview;image.setImageBitmap(bitmap);if(image==cover&&usesCoverAtmosphere())updateAtmosphere(bitmap);
        if(ArtworkCache.peek(song,side)!=null||!isShown()||pending.contains(key))return;
        if(images==null||images.isShutdown()){images=new ThreadPoolExecutor(1,1,10,TimeUnit.SECONDS,new ArrayBlockingQueue<>(16));images.allowCoreThreadTimeOut(true);}
        if(side>=1600&&(detailImages==null||detailImages.isShutdown())){detailImages=new ThreadPoolExecutor(1,1,10,TimeUnit.SECONDS,new ArrayBlockingQueue<>(2));detailImages.allowCoreThreadTimeOut(true);}
        ThreadPoolExecutor loader=side>=1600?detailImages:images;
        int generation=artGeneration;pending.add(key);try{loader.execute(()->{Bitmap result=null;try{result=ArtworkCache.load(getContext(),song,side);}catch(RuntimeException|OutOfMemoryError ignored){}final Bitmap ready=result;post(()->{if(generation!=artGeneration)return;pending.remove(key);if(ready!=null){if(key.equals(image.getTag())){image.setImageBitmap(ready);if(image==cover&&usesCoverAtmosphere())updateAtmosphere(ready);}if(cover!=null&&key.equals(cover.getTag()))cover.setImageBitmap(ready);if(list!=null)for(int i=0;i<list.getChildCount();i++){Object holder=list.getChildAt(i).getTag();if(holder instanceof Object[]){ImageView thumbnail=(ImageView)((Object[])holder)[0];if(key.equals(thumbnail.getTag()))thumbnail.setImageBitmap(ready);}}refreshGlass();}});});}catch(RejectedExecutionException busy){pending.remove(key);}
    }
    @Override protected void onSizeChanged(int w,int h,int oldw,int oldh){super.onSizeChanged(w,h,oldw,oldh);if(w>0&&h>0&&(w!=renderWidth||h!=renderHeight)){renderWidth=w;renderHeight=h;clearGroupTransition();saveScroll();post(()->{if(getWidth()==w&&getHeight()==h&&!style.equals("wall"))render();});}}
    @Override protected void onAttachedToWindow(){super.onAttachedToWindow();getViewTreeObserver().addOnScrollChangedListener(glassScroll);}
    @Override protected void onLayout(boolean changed,int l,int t,int r,int b){super.onLayout(changed,l,t,r,b);refreshGlass();}
    @Override protected void onDetachedFromWindow(){if(getViewTreeObserver().isAlive())getViewTreeObserver().removeOnScrollChangedListener(glassScroll);atmosphere.stop();transitionEpoch++;artGeneration++;clearGroupTransition();if(heroMotion!=null)heroMotion.cancel();if(selectionMotion!=null)selectionMotion.cancel();if(images!=null)images.shutdownNow();if(detailImages!=null)detailImages.shutdownNow();pending.clear();super.onDetachedFromWindow();}
}
