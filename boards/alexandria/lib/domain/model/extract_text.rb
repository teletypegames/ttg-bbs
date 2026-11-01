# frozen_string_literal: true

# The model side's text helper: the plain extract of an article (the
# TextExtracts of the Action API, explaintext) cut into sections in Markdown.
# Pure functions, no I/O; ArticleModel.from_api calls it.
module ExtractText
  # The sections nobody reads on a terminal: the plain text keeps only
  # their headings.
  SKIP = ['see also', 'references', 'notes', 'footnotes', 'sources', 'external links', 'further reading',
          'bibliography', 'jegyzetek', 'források', 'forrás', 'kapcsolódó szócikkek', 'további információk',
          'irodalom', 'külső hivatkozások', 'siehe auch', 'literatur', 'weblinks', 'einzelnachweise',
          'anmerkungen'].freeze

  # The TeX of a formula as plain text: its symbols, its functions.
  TEX = {
    'alpha' => 'α', 'beta' => 'β', 'gamma' => 'γ', 'Gamma' => 'Γ', 'delta' => 'δ', 'Delta' => 'Δ',
    'epsilon' => 'ε', 'varepsilon' => 'ε', 'theta' => 'θ', 'lambda' => 'λ', 'mu' => 'μ', 'pi' => 'π',
    'rho' => 'ρ', 'sigma' => 'σ', 'Sigma' => 'Σ', 'tau' => 'τ', 'phi' => 'φ', 'varphi' => 'φ', 'Phi' => 'Φ',
    'omega' => 'ω', 'Omega' => 'Ω', 'infty' => '∞', 'cdot' => '·', 'times' => '×', 'pm' => '±', 'div' => '÷',
    'le' => '≤', 'leq' => '≤', 'ge' => '≥', 'geq' => '≥', 'ne' => '≠', 'neq' => '≠', 'approx' => '≈',
    'equiv' => '≡', 'to' => '→', 'rightarrow' => '→', 'Rightarrow' => '⇒', 'in' => '∈', 'sum' => 'Σ',
    'prod' => 'Π', 'int' => '∫', 'partial' => '∂', 'nabla' => '∇', 'ldots' => '…', 'cdots' => '…', 'dots' => '…'
  }.freeze
  FUNCTIONS = %w[sin cos tan cot log ln exp lim max min det arg sinh cosh tanh].freeze

  module_function

  # The plain extract cut at its == level-2 == headings, as [heading,
  # markdown] pairs; the deeper headings stay in their section as Markdown
  # headings. The lead is named after the article.
  def sections(title, extract)
    parts = [[title, []]]
    formulas(extract.to_s).each_line(chomp: true) do |line|
      if (m = line.match(/\A(={2,6})\s*(.*?)\s*=+\s*\z/))
        if m[1].size == 2
          parts << [m[2], []]
        else
          parts.last[1] << "#{'#' * (m[1].size - 1)} #{m[2]}"
        end
      else
        parts.last[1] << line
      end
    end
    parts.filter_map do |name, lines|
      next if SKIP.include?(name.downcase)

      text = markdown(lines)
      [name, text] unless text.empty?
    end
  end

  # One paragraph a line in the extract, a blank line between them in
  # Markdown. A heading with nothing under it before the next one of its
  # level goes; a line the renderer would take for a heading, a code fence
  # or a quote is escaped.
  def markdown(lines)
    out = []
    lines.each do |line|
      line = line.gsub(/[ \t]{2,}/, ' ').strip
      next if line.empty?

      if (level = heading_level(line))
        out.pop while heading_level(out.last.to_s).to_i >= level
        out << line
      else
        out << escape(line)
      end
    end
    out.pop while heading_level(out.last.to_s)
    out.join("\n\n")
  end

  def heading_level(line) = line[/\A(#+) /, 1]&.size

  def escape(line) = line.match?(/\A(?:#|```|>)/) ? "\\#{line}" : line

  # A formula comes in the plain text as its MathML, one token a line, and
  # then its TeX; it is put back in its line as the TeX, made readable.
  def formulas(text)
    text = text.gsub(/\n[ \t]+\n(?:[ \t]*[^\n]*\n)*?[ \t]*\{\\displaystyle ?([^\n]*)\}[ \t]*\n(?:[ \t]*\n)?/) do
      " #{tex(::Regexp.last_match(1))} "
    end.gsub(/ +(?=[,.;:)])/, '')
    text.gsub(/\{\\displaystyle ?([^\n]*?)\}(?=\s|\z)/) { tex(::Regexp.last_match(1)) }
  end

  def tex(source)
    s = source.dup
    nil while s.gsub!(/\\[dt]?frac\{([^{}]*)\}\{([^{}]*)\}/, '(\1)/(\2)')
    nil while s.gsub!(/\\sqrt\{([^{}]*)\}/, '√(\1)')
    s = s.gsub(/\\([A-Za-z]+)/) do
      name = ::Regexp.last_match(1)
      TEX[name] || (FUNCTIONS.include?(name) ? " #{name} " : '')
    end
    s = s.gsub(/\\[,;:! ]/, ' ').gsub(/\s+([)}])/, '\1').gsub(/([_^])\{([^{}]{2,})\}/, '\1(\2)').delete('{}\\')
    s.gsub(/\s+/, ' ').strip
  end
end
