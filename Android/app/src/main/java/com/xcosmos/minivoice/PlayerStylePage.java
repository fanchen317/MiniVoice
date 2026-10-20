package com.xcosmos.minivoice;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.widget.*;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import java.util.function.IntConsumer;

/** Two native alternatives to the wall, using the same library and playback service. */
final class PlayerStylePage extends FrameLayout {
    private final Consumer<Song> play;private final IntConsumer seek;private final Runnable lyricsAction,browse;
    private List<Song> songs=new ArrayList<>();private List<Lyrics.Line> lyrics=new ArrayList<>();private Song current;
    private AppAppearance.Palette colors=new AppAppearance.Palette(false);private String style="wall";private ListView list;private TextView lyricText,listHeading;private String section="音乐库";private ImageView cover;private Bitmap displayedCover;private int position;private String lyricStatus="暂无歌词 · 点按导入";private long activeLineTime=-1;
    private final BaseAdapter adapter=new BaseAdapter(){
        public int getCount(){return songs.size();}public Song getItem(int index){return songs.get(index);}public long getItemId(int index){return getItem(index).id;}
        public View getView(int index,View recycled,android.view.ViewGroup parent){
            LinearLayout row;ImageView image;TextView title,subtitle;
            if(recycled==null){row=new LinearLayout(getContext());row.setGravity(Gravity.CENTER_VERTICAL);row.setPadding(dp(16),dp(10),dp(16),dp(10));row.setLayoutParams(new AbsListView.LayoutParams(-1,dp(72)));
                image=new ImageView(getContext());image.setScaleType(ImageView.ScaleType.CENTER_CROP);row.addView(image,new LinearLayout.LayoutParams(dp(48),dp(48)));
                LinearLayout labels=new LinearLayout(getContext());labels.setOrientation(LinearLayout.VERTICAL);labels.setPadding(dp(14),0,0,0);row.addView(labels,new LinearLayout.LayoutParams(0,-2,1));
                title=text("",15,colors.text);subtitle=text("",12,colors.secondary);title.setSingleLine(true);subtitle.setSingleLine(true);title.setEllipsize(android.text.TextUtils.TruncateAt.END);subtitle.setEllipsize(android.text.TextUtils.TruncateAt.END);subtitle.setPadding(0,dp(5),0,0);labels.addView(title);labels.addView(subtitle);row.setTag(new Object[]{image,title,subtitle});
            }else row=(LinearLayout)recycled;
            Object[] holder=(Object[])row.getTag();image=(ImageView)holder[0];title=(TextView)holder[1];subtitle=(TextView)holder[2];Song song=getItem(index);
            image.setImageBitmap(song.artworkPreview);image.setBackgroundColor(colors.line);title.setText(song.title);subtitle.setText(song.groupCount>0?song.groupCount+" 首歌曲":song.artist+" · "+song.album);title.setTextColor(current!=null&&current.id==song.id?colors.accent:colors.text);subtitle.setTextColor(colors.secondary);return row;
        }
    };
    PlayerStylePage(Context context,Consumer<Song> play,IntConsumer seek,Runnable lyricsAction,Runnable browse){super(context);this.play=play;this.seek=seek;this.lyricsAction=lyricsAction;this.browse=browse;setVisibility(GONE);}
    private int dp(int value){return Math.round(value*getResources().getDisplayMetrics().density);}
    private TextView text(String value,int size,int color){TextView result=new TextView(getContext());result.setText(value);result.setTextSize(size);result.setTextColor(color);return result;}
    void configure(String style,AppAppearance.Palette colors){this.style=style;this.colors=colors;setBackgroundColor(colors.background);setVisibility(style.equals("wall")?GONE:VISIBLE);render();}
    void setInsets(int left,int top,int right,int bottom){setPadding(left,top+dp(80),right,bottom+dp(112));}
    void setSongs(List<Song> value){songs=new ArrayList<>(value);if(listHeading!=null)listHeading.setText(section+" · "+songs.size());adapter.notifyDataSetChanged();}
    void setSection(String value){section=value.equals("歌曲")?"音乐库":value.startsWith("歌单:")?value.substring(3):value;if(listHeading!=null)listHeading.setText(section+" · "+songs.size());}
    void setSong(Song value){boolean changed=current==null||current.id!=value.id||!current.title.equals(value.title)||!current.artist.equals(value.artist);current=value;if(changed){lyrics=new ArrayList<>();lyricStatus="正在加载歌词…";if(style.equals("simple"))render();adapter.notifyDataSetChanged();}updateCover();}
    void setLyricsStatus(String message){lyricStatus=message;updateLyric();}
    void setLyrics(List<Lyrics.Line> value){lyrics=new ArrayList<>(value);updateLyric();}
    void setPosition(int value){position=value;updateLyric();updateCover();}
    void locate(long id){if(list!=null)for(int i=0;i<songs.size();i++)if(songs.get(i).id==id){list.smoothScrollToPosition(i);break;}}
    private void render(){removeAllViews();list=null;listHeading=null;lyricText=null;cover=null;displayedCover=null;if(style.equals("wall"))return;
        if(style.equals("library")){LinearLayout root=new LinearLayout(getContext());root.setOrientation(LinearLayout.VERTICAL);addView(root,new FrameLayout.LayoutParams(-1,-1));TextView heading=text(section+" · "+songs.size(),25,colors.text);listHeading=heading;heading.setTypeface(null,Typeface.BOLD);heading.setPadding(dp(20),dp(8),dp(20),dp(16));root.addView(heading);
            list=new ListView(getContext());list.setDivider(null);list.setCacheColorHint(android.graphics.Color.TRANSPARENT);list.setAdapter(adapter);list.setOnItemClickListener((parent,view,index,id)->play.accept(songs.get(index)));FrameLayout results=new FrameLayout(getContext());root.addView(results,new LinearLayout.LayoutParams(-1,0,1));results.addView(list,new FrameLayout.LayoutParams(-1,-1));TextView empty=text("暂无歌曲\n可在设置中添加音乐文件夹",15,colors.secondary);empty.setGravity(Gravity.CENTER);results.addView(empty,new FrameLayout.LayoutParams(-1,-1));list.setEmptyView(empty);return;}
        ScrollView scroll=new ScrollView(getContext());scroll.setFillViewport(true);addView(scroll,new FrameLayout.LayoutParams(-1,-1));LinearLayout body=new LinearLayout(getContext());body.setOrientation(LinearLayout.VERTICAL);body.setGravity(Gravity.CENTER_HORIZONTAL);body.setPadding(dp(28),dp(12),dp(28),dp(24));scroll.addView(body);
        cover=new ImageView(getContext());cover.setScaleType(ImageView.ScaleType.CENTER_CROP);GradientDrawable shape=new GradientDrawable();shape.setColor(colors.line);shape.setCornerRadius(dp(22));cover.setBackground(shape);cover.setClipToOutline(true);int side=Math.min(dp(300),getResources().getDisplayMetrics().widthPixels-dp(80));body.addView(cover,new LinearLayout.LayoutParams(side,side));
        TextView title=text(current==null?"选择一首歌曲":current.title,24,colors.text);title.setTypeface(null,Typeface.BOLD);title.setGravity(Gravity.CENTER);title.setPadding(0,dp(24),0,0);body.addView(title,new LinearLayout.LayoutParams(-1,-2));
        TextView artist=text(current==null?"从音乐库开始播放":current.artist+" · "+current.album,14,colors.secondary);artist.setGravity(Gravity.CENTER);artist.setPadding(0,dp(10),0,dp(24));body.addView(artist,new LinearLayout.LayoutParams(-1,-2));
        if(current==null){TextView choose=text("浏览音乐库 ›",16,colors.accent);choose.setOnClickListener(view->browse.run());body.addView(choose);}
        lyricText=text("暂无歌词",20,colors.secondary);lyricText.setGravity(Gravity.CENTER);lyricText.setLineSpacing(dp(6),1);lyricText.setPadding(0,dp(8),0,dp(20));lyricText.setOnClickListener(view->{if(activeLineTime>=0)seek.accept((int)Math.min(Integer.MAX_VALUE,activeLineTime));else lyricsAction.run();});lyricText.setOnLongClickListener(view->{lyricsAction.run();return true;});body.addView(lyricText,new LinearLayout.LayoutParams(-1,-2));updateCover();updateLyric();
    }
    private void updateCover(){if(cover==null||current==null)return;Bitmap bitmap=ArtworkCache.peek(current);if(bitmap==null)bitmap=current.artworkPreview;if(bitmap!=displayedCover){displayedCover=bitmap;cover.setImageBitmap(bitmap);}}
    private void updateLyric(){if(lyricText==null)return;if(lyrics.isEmpty()){activeLineTime=-1;lyricText.setText(lyricStatus);return;}int active=0;for(int i=0;i<lyrics.size();i++){if(lyrics.get(i).ms>position)break;if(lyrics.get(i).ms>=0)active=i;}activeLineTime=lyrics.get(active).ms;lyricText.setText(lyrics.get(active).text);}
}
