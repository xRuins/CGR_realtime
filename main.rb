require 'serialport'
require 'byebug'
require 'bindata'

#シリアルポート通信設定
$serial_port = '/dev/tty.TSND121-13111082-Blueto'
$serial_baudrate = 9600
$serial_databit = 8
$serial_stopbit = 1
$serial_paritycheck = 0
$serial_delimiter = "\n"

require './SPRING.rb'
require './GraphPlotter.rb'
require 'gnuplot'
require 'csv'

# constants for SPRING
EPSILON_SPRING = 100
EPSILON_F_SPRING = 50#10
PENDING_DEADLINE = 25
MINIMUM_LENGTH = 30#50
ALPHA = 0.25
INITIALIZE_WHEN_REPORTED = false
DUPLICATE_RATIO = 0.50

# configuration for template data
COLORS = ["yellow", "cyan", "green"]
#TEMPLATES = ["t_chop_rev3s.csv", "t_punch_rev3.csv", "t_throw_rev3sss.csv"]
TEMPLATES = ["t_o.csv", "t_t.csv", "t_x.csv"]
#TEMPLATES = ["t_o.csv", "t_t_ev.csv", "t_x_ev.csv"]

CSV_DIR = "./csv/"
# CSVからの加速度値の読み出し
def load_csv csv
    CSV.read(csv, converters: :float)
end

# 早期認識におけるジェスチャ認識アルゴリズムの判定
def judge_quick_recognition(qr_dists, gesture_number)
    d1 = qr_dists.min # 最小の距離
    d2 = qr_dists.sort[1] # 次点の距離
    d1_index = qr_dists.each_with_index.min.last # 最小の距離を取るジェスチャのインデックス

    # d1 or d2 = ∞ の時は信頼性がないのでfalse
    if d1.infinite? or d2.infinite?
        return false
        # 該当するジェスチャの距離が最小かつ，次点のジェスチャの距離との差が十分大きければtrue
    elsif ( d1 / d2 < ALPHA && gesture_number == d1_index )
        return true
    else
        #p "#{qr_dists} : failure"
        return false
    end
end

def calc_d_mins_score qr_dists, gesture_number
    d1 = qr_dists.min # 最小の距離
    d2 = qr_dists.sort[1] # 次点の距離
    return d1 / d2
end

def judge_d_min(d_mins, gesture_number)
    min_index = d_mins.index(d_mins.min)
    return min_index == gesture_number
end

def print_subsequence(subsequence, prefix = nil, suffix = nil)
    t_s = subsequence.t_s
    t_e = subsequence.t_e
    type = subsequence.type

    p "SubSequence: #{t_s} to #{t_e} as #{type}" if prefix.nil? && suffix.nil?
    p "SubSequence: #{t_s} to #{t_e} as #{type} #{suffix}" if prefix.nil? && suffix
    p "#{prefix}: #{t_s} to #{t_e} as #{type}" if prefix && suffix.nil?
    p "#{prefix}: #{t_s} to #{t_e} as #{type} #{suffix}" if prefix && suffix
end

def get_score seq, template
    seq_length = seq.last - seq.first
    template_length = template.length
    seq_d_min = seq.d_min
    return seq_d_min / (seq_length + template_length)
end

def get_faired_dists instances
    subseq_length = instances.map { |instance| instance.get_matching_length }
    dists = instances.map { |instance| instance.d_min }#d[instance.m] }

    scores = []
    subseq_length.length.times do |i|
        scores[i] = dists[i] / subseq_length[i]# emplate_length[i]#(subseq_length[i] + template_length[i])
    end

    return scores
end

def get_faired_dists2 instances
    subseq_length = instances.map { |instance| instance.get_matching_length }
    dists = instances.map { |instance| instance.dd.last }#d[instance.m] }

    scores = []
    subseq_length.length.times do |i|
        scores[i] = dists[i]# / (subseq_length[i] + template_length[i])
    end

    return scores
end

def check_subsequence_supeciousity seq, instances
    gesture_number = seq.type

    scores = get_faired_dists instances
    qr_dist = judge_quick_recognition scores, gesture_number
    if qr_dist
        return true
    else
        return false
    end
end

def calc_acceleration_variance acc, sample
    target = acc.last(sample)
    acc.transpose.each
end



def calc_xor_by_byte string
    bytes = string.scan(/.{1,#{8}}/)
    prev_byte = nil
    bytes.each do |byte|
        if prev_byte.nil?
            prev_byte = byte.to_i
        else
            prev_byte ^= byte.to_i
        end
    end

    return prev_byte.to_s(2)
end

def generate_command cmd_code, *params
    whole_cmd = String.new
    whole_cmd << header = 0x9A.to_s(2)
    whole_cmd << cmd = format("%08d", cmd_code.to_s(2))

    params.each do |param|
        whole_cmd << format("%08d", param.to_s(2))
    end
    whole_cmd << calc_xor_by_byte(whole_cmd)
    return whole_cmd
end

def read_param_to_int param
    #BinData::Int24le.read(param.join) * 9.8 / 100
#    param.do each |p|

    ret = (param[2] << 24) | (param[1] << 16) | (param[0] << 8) / 2560
    #if ret & 0x80_0000 == 0x80_0000
    #    ret -= 0x1_00_0000
    #end
    #ret
end

def check_bcc buf
    xor_result = nil
    buf[0..(buf.length-2)].each do |c|
        xor_result = (xor_result.nil? ? c : (c ^ xor_result))
    end
    buf.last == xor_result
end


#begin
#シリアルポートを開く
sp = SerialPort.new($serial_port, $serial_baudrate, $serial_databit, $serial_stopbit, $serial_paritycheck)
sp.read_timeout=10000 #受信時のタイムアウト（ミリ秒単位）

#送信（例えばこんな感じ）
#sp.puts "ARM:COUNt 1#{$serial_delimiter}"
#sp.write "INIT#{$serial_delimiter}"
#sp.write("\x9A\x8C\x00\x22#{$serial_delimiter}")
#start_measure = generate_command 0x13, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
#sp.write("#{start_measure}#{$serial_delimiter}")
#p start_measure
#sleep(10)

#write_st = sp.write("\x9A\x14\x00\x00\x01\x01\x00\x00\x00\x00\x00\x01\x01\x00\x00\x00\x14#{$serial_delimiter}")
#p write_st
#    puts sp.read

#受信（例えばこんな感じ）
#デリミターを引数として渡しておくとgetsはデリミターが受信されるまで
#あるいは設定されたタイムアウトになるまで待ちます
# initialization for accel. receiver
buf = []
raw_buf = []
acc = []
first_command_received = false
gp_pipe = IO.popen("gnuplot", "w")

# initialization for SPRING
results = []
pendings = []
spring_dists = []
dists_per_csv = []
seq_len = []
all_pendings = []
j = 0
templates = []
for h in 0..TEMPLATES.length-1 do
    templates[h] ||= load_csv(CSV_DIR + TEMPLATES[h])
end
gesture_number = templates.length-1
spring_instances = []


loop do
    got_acc = false
    input = sp.read(1)
    sample = nil
    # nilが来たら一回バッファをリセット
    if input.nil?
        buf = []
        raw_buf = []
    else
        input_num = input.unpack("C*")[0]
        if input_num == 0x9A and buf.any?
            # bccが合う場合のみ処理
            if check_bcc buf
                #p "command received"
                #p buf.join.unpack("C*")
                case buf[1]
                when 0x88
                    p "TSND121 working..."
                when 0x89
                    p "TSND121 shutdown..."
                when 0x80
                    acc_x = read_param_to_int buf[6..8]
                    acc_y = read_param_to_int buf[9..11]
                    acc_z = read_param_to_int buf[12..14]
                    p sprintf("accel. x: %2f, y: %2f, z: %2f", acc_x, acc_y, acc_z)
                    got_acc = true
                    sample = [j, acc_x, acc_y, acc_z]
                    acc << sample
                end
            end
            buf = []
            raw_buf = []
        end
        buf << input_num
        raw_buf << input
    end

    if got_acc
        j += 1
        spring_result = nil
        template_dists = []
        dists_per_sample = []
        seq_len_per_sample = []
        candidates = []
        # SPRINGによる部分シーケンスの検出
        for i in 0..(gesture_number) do
            template = templates[i]
            spring_instances[i] ||= SPRING.new(template, EPSILON_SPRING, EPSILON_F_SPRING, i).dup
            spring_result = spring_instances[i].calc(sample)
            template_dists << spring_instances[i].d_min
            dists_per_sample << spring_instances[i].d[template.length-1]
            seq_len_per_sample << spring_instances[i].get_matching_length
            # SPRINGで部分シーケンスが検出された場合
            if spring_result && spring_result.length > MINIMUM_LENGTH
                pendings << spring_result
                all_pendings << spring_result
            end
        end

        # 保留中のシーケンスがあるなら出力条件を満たすかどうか判定
        if pendings.any? && !(spring_instances.empty?)
            pendings.each do |pending|
                # 保留中のシーケンスが出力条件を満たす？
                if check_subsequence_supeciousity pending, spring_instances
                    candidates << pending
                    #print_subsequence pending, "output(p/cond): ", "at#{j.to_f/50}"
                    pendings.delete(pending)
                    # 保留中のシーケンスが出力条件を満たさない
                else
                    # 重複率の高い出力済みの部分シーケンスを検索
                    results.each do |result|
                        ratio = SubSequence.calc_overlap_ratio pending, result
                        pending_score = pending.d_min / (pending.length + templates[pending.type].length)
                        result_score = result.d_min / (result.length + templates[result.type].length)
                        # 保留中のシーケンスよりも距離が低い出力済みの部分シーケンスがあるなら破棄
                        pendings.delete(pending) if result_score < pending_score and DUPLICATE_RATIO < ratio
                    end
                    # 重複率の高い保留中の部分シーケンスを検索
                    pendings.each do |comparison|
                        ratio = SubSequence.calc_overlap_ratio pending, comparison
                        pending_score = pending.d_min / (pending.length + templates[pending.type].length)
                        comparison_score = comparison.d_min / (comparison.length + templates[comparison.type].length)
                        # 他の保留中のシーケンスよりも距離が高いなら破棄
                        pendings.delete(pending) if comparison_score < pending_score and DUPLICATE_RATIO < ratio
                    end
                end

                # 保留中のシーケンスがタイムアウトしている？
                if pending.margin_with(j) > PENDING_DEADLINE
                    # 距離を比較して最小ならば出力
                    candidates << pending
                    pendings.delete(pending)
                end
            end
        end

        # 出力候補シーケンスがある
        if candidates.any?
            if candidates.length == 1
                output = candidates.first
            else
                min_score = Float::INFINITY
                candidates.each do |seq|
                    score = get_score seq, templates[seq.type]
                    if score < min_score
                        output = seq
                        min_score = score
                    end
                end
            end
            results << output
            print_subsequence output, "output", "delay: #{(j - output.reported_at)}"
            #spring_instances = []# if INITIALIZE_WHEN_REPORTED
            spring_instances.each {|ins| ins.initialize_dists_alter } if INITIALIZE_WHEN_REPORTED
        end

        spring_dists << template_dists
        dists_per_csv << dists_per_sample
        seq_len << seq_len_per_sample

        dists_faired = []
        dists_per_csv.zip(seq_len).each do |dists, ss|
            dists_ps = []
            dists.zip(ss).each { |dist, s| dists_ps << dist / s }
            dists_faired << dists_ps
        end
        gp_pipe.puts "set term x11"
        #gp_pipe.puts "set yrange [-20:20]\n"
        if j < 50
            gp_pipe.puts "set xrange [0:#{j}]\n"
        else
            gp_pipe.puts "set xrange [#{j-50}:#{j}]\n"
        end
        gp_pipe.puts "set xlabel \"time\"\n"
        gp_pipe.puts "set ylabel \"acceleration\""
        gp_pipe.puts "set grid"
        # x axis
        gp_pipe.puts "plot '-' notitle with line linecolor rgb \"black\" linewidth 2"
        acc.each do |a|
            gp_pipe.puts "#{a[0]}, #{a[1]}"#{}", #{a[2]} #{a[3]}"
        end
        gp_pipe.puts 'e'
        # y axis
        gp_pipe.puts "plot '-' notitle with lines linecolor rgb \"red\" linewidth 2"
        acc.each do |a|
            gp_pipe.puts "#{a[0]}, #{a[2]}"
        end
        gp_pipe.puts 'e'
        # z axis
        gp_pipe.puts "plot '-' notitle with lines linecolor rgb \"blue\" linewidth 2"
        acc.each do |a|
            gp_pipe.puts "#{a[0]}, #{a[3]}"
        end
        gp_pipe.puts 'e'
        res = results.compact
        p results
        res && res.each do |seq|
            p "plot: #{seq.t_s} to #{seq.t_e} ( template: #{seq.type}, d_min: #{seq.d_min}, score: #{seq.d_min / (25+(seq.t_e - seq.t_s) )}"
            cols = ["yellow", "cyan", "green"]
            #        plot.arbitrary_lines << "set style rect fc lt -1 fs solid 0.15"
            offset = 0.2*seq.type
            gp_pipe.puts "set object #{i} rectangle from #{seq.t_s-offset},5 to #{seq.t_e},#{-5+offset} fc rgb \"#{cols[seq.type]}\" fs transparent solid 0.5"
            #set object 2 rect from 0,0 to 2,3 fc lt 1
            i+= 1
        end
        gp_pipe.puts "replot"
        #GraphPlotter::plot_graph acc, results.compact
    end
end
#あとは受信された内容を解釈するだけ

#シリアルポートを閉じる
#rescue Interrupt
p 'interruputed by user'
sp.close
gp_pipe.close
p 'closed serial port'
#end

#        begin
#            p input.unpack("H*").pop.scan(/[0-9a-f]{2}/).join(" ")
#        rescue
#            p "no input"
#        end

#sp.readline(1)
#p sp.unpack("H*").pop.scan(/[0-9a-f]{2}/).join(" ")
#received_data = sp.gets
#c = received_data.pop.scan(/[0-9a-f]{2}/).join(" ")
#        c = [sp.getc].pack('c') #sp.getc.pop.scan(/[0-9a-f]{2}/).join(" ")
#continue if c.nil?
#if c == "\x9A"
#    p "received #{received_cmd.getc.pop.scan(/[0-9a-f]{2}/).join(" ")}"
#    received_cmd = String.new
#else
#    received_cmd = received_cmd + c
#end

#        line = sp.gets("\n")
#line = sp.readline("\x9A")
#unless line.nil?
#p "#{line.unpack("H*").pop.scan(/[0-9a-f]{2}/).join(" ")}\n"
#end
