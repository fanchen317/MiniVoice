package com.xcosmos.minivoice;

import android.content.Context;
import android.net.Uri;
import java.io.DataInputStream;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.Charset;
import java.util.Arrays;

/** Bounded fallback for ID3 text tags that device media providers often omit. */
final class AudioTags {
    String title,artist,album;
    byte[] picture;
    static AudioTags read(Context context,Uri uri,boolean artwork){
        try(InputStream input=context.getContentResolver().openInputStream(uri)){return read(input,artwork);}
        catch(Exception ignored){return new AudioTags();}
    }
    static AudioTags read(InputStream input,boolean artwork){
        AudioTags tags=new AudioTags();
        try{
            if(input==null)return tags;
            DataInputStream stream=new DataInputStream(input);byte[] header=new byte[10];stream.readFully(header);
            if(header[0]!='I'||header[1]!='D'||header[2]!='3')return tags;
            int version=header[3];if(version<2||version>4)return tags;
            int size=synchsafe(header,6);if(size<=0||size>16*1024*1024)return tags;
            byte[] data=new byte[size];stream.readFully(data);
            if((header[5]&128)!=0&&version<4)data=unsync(data);
            int pos=0;
            if((header[5]&64)!=0&&version>=3){if(data.length<4)return tags;pos=version==4?synchsafe(data,0):integer(data,0)+4;}
            while(pos>=0&&pos+(version==2?6:10)<=data.length){
                int length=version==2?6:10;
                String id=new String(data,pos,version==2?3:4,StandardCharsets.ISO_8859_1);
                int count=version==2?((data[pos+3]&255)<<16)|((data[pos+4]&255)<<8)|(data[pos+5]&255):version==4?synchsafe(data,pos+4):integer(data,pos+4);
                if(count<=0||count>data.length-pos-length)break;
                int flags=version==2?0:data[pos+9]&255;
                if((version==3&&(flags&224)!=0)||(version==4&&(flags&77)!=0)){pos+=length+count;continue;}
                byte[] frame=Arrays.copyOfRange(data,pos+length,pos+length+count);
                if(version==4&&((flags&2)!=0||(header[5]&128)!=0))frame=unsync(frame);
                if(id.equals("TIT2")||id.equals("TT2"))tags.title=text(frame);
                if(id.equals("TPE1")||id.equals("TP1"))tags.artist=text(frame);
                if(id.equals("TALB")||id.equals("TAL"))tags.album=text(frame);
                if(artwork&&(id.equals("APIC")||id.equals("PIC"))&&tags.picture==null){
                    int index=id.equals("PIC")?4:1;
                    if(id.equals("APIC")){while(index<frame.length&&frame[index]!=0)index++;index++;}
                    index++; // picture type
                    int step=frame.length>0&&(frame[0]==1||frame[0]==2)?2:1;
                    while(index+step<=frame.length){boolean end=frame[index]==0&&(step==1||frame[index+1]==0);index+=step;if(end)break;}
                    if(index<frame.length)tags.picture=Arrays.copyOfRange(frame,index,frame.length);
                }
                pos+=length+count;
            }
        }catch(Exception ignored){}
        return tags;
    }
    private static int integer(byte[] bytes,int i){return ByteBuffer.wrap(bytes,i,4).getInt();}
    private static int synchsafe(byte[] b,int i){return ((b[i]&127)<<21)|((b[i+1]&127)<<14)|((b[i+2]&127)<<7)|(b[i+3]&127);}
    private static byte[] unsync(byte[] bytes){byte[] out=new byte[bytes.length];int n=0;for(int i=0;i<bytes.length;i++){out[n++]=bytes[i];if((bytes[i]&255)==255&&i+1<bytes.length&&bytes[i+1]==0)i++;}return Arrays.copyOf(out,n);}
    private static String text(byte[] frame){
        if(frame.length<2)return null;
        Charset charset=frame[0]==1?StandardCharsets.UTF_16:frame[0]==2?StandardCharsets.UTF_16BE:StandardCharsets.UTF_8;
        String value;
        try{value=charset.newDecoder().onMalformedInput(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(frame,1,frame.length-1)).toString();}
        catch(Exception ignored){value=new String(frame,1,frame.length-1,frame[0]==0?Charset.forName("GB18030"):charset);}
        int end=value.indexOf('\0');return (end<0?value:value.substring(0,end)).trim();
    }
    static boolean valid(String value){return value!=null&&!value.isBlank()&&!value.equals("<unknown>")&&!value.equals("未知");}
    static String choose(String primary,String fallback){return valid(primary)?primary.trim():fallback;}
    static String[] filename(String name){
        String clean=name==null?"未知歌曲":name.replaceFirst("\\.[^.]+$", "").replaceFirst("^\\s*\\d{1,4}\\s*[-._、]\\s*", "").trim();
        String[] parts=clean.split("\\s+-\\s+",2);
        return parts.length==2?new String[]{parts[1].trim(),parts[0].trim()}:new String[]{clean,"未知歌手"};
    }
}
