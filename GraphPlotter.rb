module GraphPlotter
    # グラフへの印字
    def self.plot_graph query, result
        Gnuplot.open(false) do |gp|
            Gnuplot::Plot.new(gp) do |plot|
                plot.arbitrary_lines << "set term x11"
                plot.arbitrary_lines << "set output"
                plot.title    ""
                plot.xlabel   "time (s)"
                plot.ylabel   "acceleration (m/s^2)"
                #                plot.xrange "[0:20]"
                plot.yrange "[-10:5]"
                #plot.arbitrary_lines << "set xtics 5"
                #plot.arbitrary_lines << "set mxtics 1"
                #plot.arbitrary_lines << "set size ratio 0.125"
                #      plot.xrange "[0:6]""
                #      plot.arbitrary_lines << "set xtics 1"
                #      plot.arbitrary_lines << "unset autoscale x"
                plot.grid
                t = []
                x = []
                y = []
                z = []
                "set term x11"
                "set output"

                query.each do |q|
                    t << q[0]
                    x << q[1]
                    y << q[2]
                    z << q[3]
                    #      pp "q: #{t}, #{x}, #{y}, #{z}"
                end

                a = Gnuplot::DataSet.new( [t, x] ) do |ds|
                    ds.with = "lines"
                    ds.linewidth = 2
                    ds.linecolor = "rgb \"black\""
                    ds.notitle
                end
                byebug

                # 加速度のx軸
                plot.data << Gnuplot::DataSet.new( [t, x] ) do |ds|
                    ds.with = "lines"
                    ds.linewidth = 2
                    ds.linecolor = "rgb \"black\""
                    ds.notitle
                end

                byebug

                plot.data << Gnuplot::DataSet.new( [t, y] ) do |ds|
                    ds.with = "lines"
                    ds.linewidth = 2
                    ds.linecolor = "rgb \"red\""
                    ds.notitle
                end

                plot.data << Gnuplot::DataSet.new( [t, z] ) do |ds|
                    ds.with = "lines"
                    ds.linewidth = 2
                    ds.linecolor = "rgb \"blue\""
                    ds.notitle
                end
                result && result.each do |seq|
                    p "plot: #{seq.t_s} to #{seq.t_e} ( template: #{seq.type}, d_min: #{seq.d_min}, score: #{seq.d_min / (25+(seq.t_e - seq.t_s) )}"
                    cols = ["yellow", "cyan", "green"]
                    #        plot.arbitrary_lines << "set style rect fc lt -1 fs solid 0.15"
                    offset = 0.2*seq.type
                    plot.arbitrary_lines << "set object #{i} rectangle from #{seq.t_s-offset},5 to #{seq.t_e},#{-5+offset} fc rgb \"#{cols[seq.type]}\" fs transparent solid 0.5"
                    #set object 2 rect from 0,0 to 2,3 fc lt 1
                    i+= 1
                end

            end
        end
    end
end
