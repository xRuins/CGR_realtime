class SubSequence
  attr_reader :first, :last, :t_s, :t_e, :type, :d_min, :reported_at

  def initialize (first, last, t_s, t_e, type, d_min, reported_at)
    @first = first
    @last = last
    @t_s = t_s
    @t_e = t_e
    @type = type
    @d_min = d_min
    @reported_at = reported_at
  end

  def self.get_minimum subsequences, templates
    result = nil
    min = Float::INFINITY
    subsequences.each do |seq|
#      seq_score = seq.d_min / templates[seq.type].length / Math.sqrt(2*(seq.t_e - seq.t_s))
#      seq_score = seq.d_min / Math.sqrt(templates[seq.type].length + (seq.t_e - seq.t_s))
#      seq_score = seq.d_min / templates[seq.type].length / Math.sqrt( 2 * (seq.t_e - seq.t_s))

      seq_score = (seq.d_min / (templates[seq.type].length + seq.t_e - seq.t_s))

#      seq_score = (seq.d_min / (templates[seq.type].length ** 2) + (seq.t_e - seq.t_s) ** 2)
      if seq_score < min
        result = seq
        min = seq_score
      end
    end
    return result
  end

  def self.calc_overlap_ratio seq1, seq2
      #p "#{seq1.first} to #{seq1.last}, #{seq2.first} to #{seq2.last}"
      # 重なっていない場合0を返す
      return 0 if seq1.last < seq2.first or seq2.last < seq1.first
      # seq1 -> 1 and 2 -> seq2 の場合

      seq1_length = (seq1.last - seq1.first).to_f
      # A contains B
      return (seq2.last - seq2.first) / seq1_length if (seq1.first < seq2.first) && (seq2.last < seq1.last)
      # B contains A
      return 1 if (seq2.first < seq1.first) && (seq1.last < seq2.last)
      # A->AB->B
      return (seq1.last - seq2.first) / seq1_length if seq1.first < seq2.first
      # B->BA->A
      # seq2 -> 2 and 1 -> seq1 の場合
      return (seq2.last - seq1.first) / seq1_length if seq1.first > seq2.first
      # 完全に重複している場合
      return 1
  end

  def margin_with t
      t - @reported_at
  end

  def length
      @last - @first
  end

  def divided_d_min
      @d_min / length
  end
end
