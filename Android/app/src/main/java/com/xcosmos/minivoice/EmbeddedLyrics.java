package com.xcosmos.minivoice;

import android.content.Context;
import android.net.Uri;
import java.io.*;
import java.nio.charset.StandardCharsets;

final class EmbeddedLyrics {
    static String read(Context context,Uri uri){try(InputStream input=context.getContentResolver().openInputStream(uri)){return read(input);}catch(Exception ignored){return "";}}
    static String read(InputStream input)throws Exception{
        if(input==null)return "";BufferedInputStream buffered=new BufferedInputStream(input);buffered.mark(12);byte[] header=new byte[4];new DataInputStream(buffered).readFully(header);buffered.reset();
        if(header[0]=='I'&&header[1]=='D'&&header[2]=='3'||header[0]=='f'&&header[1]=='L'&&header[2]=='a'&&header[3]=='C')return AudioTags.read(buffered,false).lyrics;
        DataInputStream stream=new DataInputStream(buffered);
        for(int atoms=0;atoms<10000;atoms++){
            long length;try{length=Integer.toUnsignedLong(stream.readInt());}catch(EOFException end){return "";}byte[] type=new byte[4];stream.readFully(type);String name=new String(type,StandardCharsets.ISO_8859_1);int head=8;
            if(length==1){length=stream.readLong();head=16;}if(length<head)return "";
            long body=length-head;
            if(name.equals("moov")&&body<=16*1024*1024){byte[] data=new byte[(int)body];stream.readFully(data);return atoms(data,0,data.length,false,0);}
            while(body>0){long skip=stream.skip(body);if(skip<=0){if(stream.read()<0)return "";skip=1;}body-=skip;}
        }return "";
    }
    private static String atoms(byte[] data,int start,int end,boolean lyric,int depth){
        if(depth>8)return "";
        for(int pos=start;pos+8<=end;){long size=Integer.toUnsignedLong(java.nio.ByteBuffer.wrap(data,pos,4).getInt());if(size<8||size>end-pos)return "";String type=new String(data,pos+4,4,StandardCharsets.ISO_8859_1);int body=pos+8,limit=pos+(int)size;
            if(lyric&&type.equals("data")&&body+8<=limit)return new String(data,body+8,limit-body-8,StandardCharsets.UTF_8).trim();
            if(type.equals("udta")||type.equals("meta")||type.equals("ilst")||type.equals("©lyr")){
                String result=atoms(data,body+(type.equals("meta")?4:0),limit,lyric||type.equals("©lyr"),depth+1);if(!result.isEmpty())return result;
            }pos=limit;
        }return "";
    }
}
