require 'tempfile'
# TODO: look for a .openeditorrc file and parse it. Look for places to put the
# temp files besides the default (which will be /tmp)
# TODO: make the default temp file directory /tmp
class OpenEditor
  DEBIAN_SENSIBLE_EDITOR = '/usr/bin/sensible-editor'
  MACOSX_OPEN_CMD = 'open'
  XDG_OPEN = '/usr/bin/xdg-open'

  def self.sensible_editor
    return ENV['VISUAL'] if ENV['VISUAL']
    return ENV['EDITOR'] if ENV['EDITOR']
    return MACOSX_OPEN_CMD if Platform::IMPL == :macosx
    if Platform::IMPL == :linux
      return XDG_OPEN               if File.executable?(XDG_OPEN)
      return DEBIAN_SENSIBLE_EDITOR if File.executable?(DEBIAN_SENSIBLE_EDITOR)
    end
    raise 'Could not determine what editor to use. Please specify.'
  end

  attr_accessor :editor
  def initialize(editor = :vim)
    @editor = editor.to_s
    case @editor
    when 'mate'
      @editor = 'mate -w'
    when 'vim'
      @editor = 'vim -c ":set ft=ruby"'
    when 'mvim'
      @editor = 'mvim -fc ":set ft=ruby"'
    when 'subl'
      @editor = 'subl -w'
    end
  end

  def open_editor
    unless @file
      @file = Tempfile.new('irb_tempfile')
    end
    raise "command `#{@editor.split.first}` not found" if(system("which '#{@editor.split.first}'") == false)
    system("#{@editor} #{@file.path}")
    lines = File.read(@file.path).gsub('\r', '\n')
    lines.split('\n').each { |l| Readline::HISTORY << l } # update history
    puts 'Running the following:', '--------------'
    puts lines, '--------------', ''
    Object.class_eval(lines)
    rescue Exception => error
      # puts @file.path
      puts error
  end
end

module IRBExtension
  def open_editor(editor = OpenEditor.sensible_editor)
    unless IRB.conf[:open_editors] && IRB.conf[:open_editors][editor]
      IRB.conf[:open_editors] ||= {}
      IRB.conf[:open_editors][editor] = OpenEditor.new(editor)
    end
    IRB.conf[:open_editors][editor].open_editor
  end

  def handling_jruby_bug(&block)
    if RUBY_PLATFORM =~ /java/
      puts 'JRuby IRB has a bug which prevents successful IRB vi/emacs editing.'
      puts 'The JRuby team is aware of this and working on it. But it might be unfixable.'
      puts '(http://jira.codehaus.org/browse/JRUBY-2049)'
    else
      yield
    end
  end

  def vi
    handling_jruby_bug {open_editor(:vim)}
  end

  def mvim
    handling_jruby_bug {open_editor(:mvim)}
  end

  def subl
    handling_jruby_bug {open_editor(:subl)}
  end

  def mate
    open_editor(:mate)
  end

  # TODO: Hardcore Emacs users use emacsclient or gnuclient to open documents in
  # their existing sessions, rather than starting a brand new Emacs process.
  def emacs
    handling_jruby_bug {open_editor(:emacs)}
  end
end

# Since we only intend to use this from the IRB command line, I see no reason to
# extend the entire Object class with this module when we can just extend the
# IRB main object.
self.extend IRBExtension if Object.const_defined? :IRB


