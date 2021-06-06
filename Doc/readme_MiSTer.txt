FPGA版8801互換機readme:
本RTLはMiSTer上にPC-8801mkII SR相当の機能を構築する物です。

本RTLに関しては、フリーソフトウェアです。
・Z80 CPUのIP : T80はDaniel Wallnerさんに著作権があります。
一部は えすび さんと私、プーによって修正されています。
えすび さんのブログ:Ｐ６つくろうブログ
http://sbeach.seesaa.net/

その他のRTLに関しては私、プーにあります。
このRTLに含まれるファイルに関しては一切無保証です。2次的被害を含む一切の責任は
負いません。

動作異常等に関しては、ブログ
http://fpga8801.seesaa.net/
内のメッセージやコメントにて連絡をお願いいたします。

使用方法:
本RTLはAltera社の開発環境 QuartusII web editionにて主に開発されており、
本配布もQuartusIIのarchive機能にてパッケージ化されております。
本RTLをProject→Restore archived projectにて展開を行い
(このファイルが開けている時点で完了していると思いますが)
コンパイルを行います。

準備が出来たらStart Compilationにてコンパイルを行ってください。
.rbfファイルと.sofファイルが作成されます。.rbfファイルはMiSTerのSDカード
ルートディレクトリにファイル名をMiSTer標準に合わせて修正し、保存してください。
.sofファイルはJTAGモードで書き込みが可能です。

MiSTerからの起動時にBIOSイメージをMiSTerのSDカードからロードします。
/PC8801mk2SR/boot.romとして下記配置になったものを作成し、保存してください。
00000～ N88BASIC
08000～ N-BASIC
10000～ N88 4th-0
12000～ N88 4th-1
14000～ N88 4th-2
16000～ N88 4th-3
18000～ FONT(8x16)
19000～ 簡易グラフィックスフォント(添付Font/graphfont.bin)
1a000～ DISK ROM
20000～ KANJI1
40000～ KANJI2
ところどころに虫食い配置になっていますのでブランクファイルを入れるなり、
バイナリエディタで結合するなりして上記オフセットになるように
BIOSイメージを作成してください。

本RTLはSDRAMボード(32MB)とIOボード上の2nd SDカードを使用します。
