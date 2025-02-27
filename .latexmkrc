# カレントディレクトリ変更
$do_cd = 1;

# fmtlatexの呼び出し
$pdf_mode = 3;
$latex = 'internal fmtlatex uplatex %Z %Y %A %S %R -synctex=1 -file-line-error -halt-on-error %O';
$dvipdf = 'dvipdfmx %O -o %D %S';
$max_repeat = 5;

# 作業パス
my $comdir=$ENV{HOME};
my $comname=".latexmk";
my $pwd=`pwd`;
chomp $pwd;

# fmtlatex メインルーチン
{
    # 拡張子を登録
    $clean_ext="$clean_ext fmt";
    my $initial = 1;

    sub fmtlatex {
        # 引数読込
        my ($engine, $outpath, $auxpath, $basename, $texname, $jobname, @args) = @_;
        my $options = join(' ', @args);

        # 初回実行時
        if ($initial == 1){
            $initial = 0;
            # フォーマット生成フラグ
            my $flag = 0;
            print "fmtlatex: checking if the preamble changed...\n";
            if (&check_preamble_change($auxpath,$jobname,$texname) == 0){
                print "fmtlatex: the preamble is not changed.\n";
                print "fmtlatex: checking if the common fmt file is owned...\n";
                if (&check_com_owned("$pwd/$texname") == 0){
                    print "fmtlatex: the common fmt file is not owned.\n";
                    $flag = 1;
                }else{
                    print "fmtlatex: the common fmt file is owned.\n";
                }
            }else{
                print "fmtlatex: the preamble is changed.\n";
                $flag = 1;
            }
            if ($flag == 1){
                print "rewriting the common fmt file in ini mode...\n";
                # フォーマット生成
                my $iniret=Run_subst("$engine -ini $options -output-directory=\"$comdir\" -jobname=\"$comname\" \\\&$engine mylatexformat.ltx $texname");
                if($iniret == 0){
                    print "fmtlatex: the common fmt file rewrited. saving preamble...\n";
                    &memorize_preamble_change($auxpath,$jobname);
                    &hold_com("$pwd/$texname");
                }else{
                    print "fmtlatex: failed to rewrite the common fmt file.\n";
                    &forget_preamble_change($auxpath,$jobname);
                    &throw_com("$pwd/$texname");
                    return $iniret;
                }
            }else{
                print "keep the common fmt file.\n";
                &forget_preamble_change($auxpath,$jobname);
            }
        }
        print "fmtlatex: the common fmt file is ready, so running normal latex... \n";
        # 通常のタイプセット
        my $finalres = Run_subst("$engine -fmt \"$comdir/$comname\" $options $texname");
        return $finalres;
    }
}

# 共有フォーマットファイルの確認・確保・破棄
{
    # 確認
    sub check_com_owned(){
        my $path=$_[0];
        open(my $fh, "<", "$comdir/$comname.info");
        my $holder=<$fh>;
        close($fh);
        if($path eq $holder){
            return 1;
        }else{
            return 0;
        }
    }
    # 確保
    sub hold_com(){
        my $path=$_[0];
        open(my $fh, ">", "$comdir/$comname.info");
        print $fh "$path";
        close($fh);
    }
    # 破棄(生成失敗時用)
    sub throw_com(){
        open(my $fh, ">", "$comdir/$comname.info");
        print $fh "";
        close($fh);
    }
}

# プリアンブル差分検知
{
    my $prea_ext = "prea";
    $clean_ext="$clean_ext $prea_ext";

    # プリアンブル抽出用のコマンド
    # \endofdumpまたは\begin{document}まで読み出して保存
    my $gethead = "awk '!/%.*/{if (p) print}BEGIN{p=1}/\\\\endofdump/{p=0}/\\\\begin\\{document\\}/{p=0}'";
    my $comphead = "sed -e 's/ *\$//g' -e 's/%.*\$//g'";

    sub check_preamble_change{
        print "check_preamble_change\n";
        my ($auxpath, $basename, $texname) = @_;
        my $preapath="$auxpath$basename.$prea_ext";
        # プリアンブル部の一時ファイルをクリア
        system("echo \"\" > \"$preapath.tmp\"");
        system("echo \"\" > \"$preapath.tmp\"");

        my $chain_flag=1;
        # subfilesによるプリアンブル依存が終わるまで続ける
        do{
            system("$gethead \"$texname\"|$comphead >> \"$preapath.tmp\"");
            system("echo \"\" >> \"$preapath.tmp\"");

            # subfilesの利用を検出
            # 第1行が\documentclass[親ファイルパス]{subfiles}であればsubfiles使用とする
            my $mastername = `head -n 1 "$texname"`;
            if ($mastername =~ /^ *\\documentclass\[.*\]\{subfiles\} *$/){
                $mastername =~ s/^ *\\documentclass\[//g;
                $mastername =~ s/\]\{subfiles\} *$//g;
            }else{
                $mastername = "";
            }
            chomp($mastername);
            # $masternameはsubfilesを利用していれば拡張子なしの親ファイルパスが入っている
            if ($mastername ne ""){
                $texname = "$mastername.tex";
            }else{
                $chain_flag=0;
            }
        }while($chain_flag == 1);
    
        # input先を読み込む
        # $preapath.tmpの中身を一行ずつ読む
        &process_input_files($preapath);

        # 比較

        my $checkret = system("diff -Bb \"$preapath.tmp\" \"$preapath\"");
        return $checkret;

        sub process_input_files{
            my ($preapath) = @_;
            #プリアンブル読み込み制限（inputの循環回避用）
            my $loading_limit=1000;
            open(my $fh, '<', $preapath.".tmp") or die "Error: $!\n";
            print "Processing $preapath.tmp\n";
            my $i=0;
            while (my $line = <$fh>) {
                $i=$i+1;
                last if $i >= $loading_limit; 
                if ($line =~ /\\input\{([^}]*)\}/) {
                    my $inputname = $1;
                    $inputname =~ s/\} *$//g;
                    print "Found input directive: $inputname\n";
                    system("$gethead \"$inputname\"|$comphead >> \"$preapath.tmp\"");
                    system("echo \"\" >> \"$preapath.tmp\"");
                }
            }
        }
    }
    sub forget_preamble_change{
        my ($auxpath, $basename) = @_;
        system("rm \"$auxpath$basename.$prea_ext.tmp\"");
    }
    sub memorize_preamble_change{
        my ($auxpath, $basename) = @_;
        system("mv \"$auxpath$basename.$prea_ext.tmp\" \"$auxpath$basename.$prea_ext\"");
    }
}


# bibtex系
$bibtex_use=2;
$bibtex = 'upbibtex %O %S';
$biber = 'biber --bblencoding=utf8 -u -U --output_safechars %O %S';

# index
$makeindex = 'upmendex %O -o %D %S -s jpbase';

# ヴューワ
$dvi_previewer = "open %S";
$pdf_previewer = "open %S";

# 出力フォルダ指定
$out_dir = "out";
# 中間ファイルを別フォルダに隠しておける
$emulate_aux = 1;
$aux_dir = ".tex_intermediates";

# 中間ファイル登録
$clean_ext="$clean_ext run.xml";