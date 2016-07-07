require './SubSequence.rb'
require 'byebug'

class SPRING
    attr_reader :d_mins, :d, :dd, :d_min, :m, :log_d_m, :path_points
    def initialize(template, epsilon, epsilon_f, gesture_number)
        @m = template.length
        @dd = [0]
        @dd.fill(Float::INFINITY, 1, @m)
        @epsilon = epsilon
        @epsilon_f = epsilon_f
        @sd = []
        @t = 0
        @d = []
        @s = []
        @log_d_m = []
        @t_s = nil
        @t_e = nil
        @t_ss = []
        @t_es = []
        @d_min = Float::INFINITY
        @d_min_t = nil
        @d_mins = []
        @path_points = []
        @x = []
        @y = template
        @type = gesture_number
        @template_ratio = get_template_ratios
        p @template_ratio
    end

    def get_template_ratios
        ratio = []
        for i in 1..(@y.transpose.length-1) do
            ratio << get_amplitude_of_template(i)
            division = ratio.min
        end
        p "raw: #{ratio}"
        ret_ratio = []
        ratio.each do |r|
            ret_ratio << division / r * 10
        end
        return ret_ratio
    end

    def get_amplitude_of_template axis
        template = @y.transpose
        #        template[axis].max.abs# - template[axis].min
        [template[axis].max.abs, template[axis].min.abs].max
    end

    def get_matching_length
        @t - @s[@m]
    end

    def calc sample
        @x.push(sample)
        @t += 1

        # initialize d and s
        @d[0] = 0
        @s[0] = @t

        for i in 1..@m do
            # calculate distance
            d_best = [@d[i-1], @dd[i], @dd[i-1]].min
            @d[i] = (@x[@t-1][1] - @y[i-1][1]) ** 2 * @template_ratio[0] +
            (@x[@t-1][2] - @y[i-1][2]) ** 2 * @template_ratio[1] +
            (@x[@t-1][3] - @y[i-1][3]) ** 2 * @template_ratio[2] +
            d_best


            #      @d[i] = (@x[@t-1] - @y[i-1]) ** 2 + d_best
            # calculate point
            if (@d[i-1] == d_best)
                @s[i] = @s[i-1]
            elsif (@dd[i] == d_best)
                @s[i] = @sd[i]
            elsif (@dd[i-1] == d_best)
                @s[i] = @sd[i-1]
            end
        end

        ret = judge_report

        if ( @d[@m] <= @epsilon && @d[@m] < @d_min )
            @d_min = @d[@m]
            @d_min_t = @t
            @t_s = @s[@m]
            @t_e = @t
        end

        @dd = @d.dup
        @sd = @s.dup
        @t_ss.delete_at(0) if @epsilon_f != nil && @t_ss.length > @epsilon_f
        @t_ss.push(@t_s)
        @t_es.delete_at(0) if @epsilon_f != nil && @t_es.length > @epsilon_f
        @t_es.push(@t_e)

        @d_mins[@t] = @d_min
        @log_d_m << @d[@m]
        ret
    end

    def judge_report
        if @d_min <= @epsilon
            for i in 1..@m do
                # report subseq if any
                unless (@d[i] >= @d_min || @s[i] > @t_e || judge_force_report)
                    return false
                end
            end

            result = SubSequence.new(@t_s, @t_e, @x[@t_s][0], @x[@t_e][0], @type, @d_min, @t)
            @d_min = Float::INFINITY
            @d_min_t = nil
            initialize_dists
            return result
        end
    end

    def judge_force_report
        if @epsilon_f == nil || @t_ss.length < @epsilon_f
            return false
        else
            @t_ss.each do |_t_s|
                return false if _t_s != @t_s
            end
            @t_es.each do |_t_e|
                return false if _t_e != @t_e
            end
        end

        return true
    end

    def initialize_dists
        for j in 1..@m do
            if @s[j] <= @t_e
                @d[j] = Float::INFINITY
            end
        end
    end

    def initialize_dists_alter
        for j in 1..@m do
            if @s[j] <= @t
                @d[j] = Float::INFINITY
            end
        end
    end

    def calculate_variance data
        sum_x = 0
        sum_y = 0
        sum_z = 0
        var = 0
        data.each do |sample|
            sum_x += sample[1]
            sum_y += sample[2]
            sum_z += sample[3]
        end
        n = data.length
        mean_x = sum_x / n
        mean_y = sum_y / n
        mean_z = sum_z / n
        data.each do |sample|
            var += (sample[1] - mean_x) ** 2
            var += (sample[2] - mean_y) ** 2
            var += (sample[3] - mean_z) ** 2
        end
        var /= n
        return var
    end

    def calc_difference sample
        res = 0
        calc_range = [(@t-sample), 0].max..@t
        for i in calc_range do
            next if @t <= 2 # t <= 1 ならスキップ(t[-1]が存在しない)
            #res += @log_d_m[i-2] - @log_d_m[i-1]?
            res += @log_d_m[i-1] - @log_d_m[i-2]
        end
        res = Float::INFINITY if Float::INFINITY*-1 == res # -Infinityなら反転
        return res
    end
end
