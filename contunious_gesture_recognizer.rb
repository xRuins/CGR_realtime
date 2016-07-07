require './SPRING.rb'
require './GraphPlotter.rb'
require 'byebug'
require 'csv'
require 'pp'
require 'gnuplot'

class ContuniousGestureRecognizer
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
TEMPLATES = ["t_o.csv", "t_t.csv", "t_x_ref.csv"]
#TEMPLATES = ["t_o.csv", "t_t_ev.csv", "t_x_ev.csv"]

CSV_DIR = "./csv/"
OUTPUT_DIR = "./output/"
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
    template_length = instances.map { |instance| instance.m }
    dists = instances.map { |instance| instance.d_min }#d[instance.m] }

    scores = []
    subseq_length.length.times do |i|
        scores[i] = dists[i] / subseq_length[i]# emplate_length[i]#(subseq_length[i] + template_length[i])
    end

    return scores
end

def get_faired_dists2 instances
    subseq_length = instances.map { |instance| instance.get_matching_length }
    template_length = instances.map { |instance| instance.m }
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


Dir.glob("#{CSV_DIR}/*.csv") do |csv|
    p "processing #{csv} ..."
    query_data = load_csv(csv)
    templates = []
    for h in 0..TEMPLATES.length-1 do
        templates[h] ||= load_csv(CSV_DIR + TEMPLATES[h])
    end
    gesture_number = templates.length-1
    spring_instances = []

    results = []
    pendings = []
    spring_dists = []
    dists_per_csv = []
    seq_len = []
    all_pendings = []
    j = 0
    query_data.each do |sample|
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
                    faired_dists = get_faired_dists spring_instances
                    #if judge_d_min faired_dists, pending.type
                        candidates << pending
                        print_subsequence pending, "output: ", "#{faired_dists}, at #{j.to_f/50}"

#                    else
#                        print_subsequence pending, "invoked: ", "#{faired_dists}, at #{j.to_f/50}"
#                    end
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
    end


    dists_faired = []
    dists_per_csv.zip(seq_len).each do |dists, ss|
        dists_ps = []
        dists.zip(ss).each { |dist, s| dists_ps << dist / s }
        dists_faired << dists_ps
    end

    GraphPlotter::plot_graph query_data, results.compact, csv, dists_per_csv, all_pendings, "[0:1000]"#, templates
    #GraphPlotter::plot_graph query_data, results.compact, "#{csv}_sl", seq_len, "[0:1000]"#, templates
    #GraphPlotter::plot_graph query_data, results.compact, "#{csv}_dm", spring_dists, "[0:1000]"#, templates
    #GraphPlotter::plot_graph query_data, results.compact, "#{csv}_df", dists_faired, "[0:100]"#, templates
    #GraphPlotter::plot_graph query_data, nil, "#{csv}_wo", dists_per_csv
end
