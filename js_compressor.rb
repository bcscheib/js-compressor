
require 'yui/compressor'
require 'pry'

class Compressor
	attr_accessor :manifest_files, :manifest_body, :cpressor
	def initialize parent
		puts "Javasript listener initializing..DONE"
		@cpressor = YUI::JavaScriptCompressor.new
		compile_manifest
		parent.watch(/manifest\.txt/) { |m| compile_manifest }
    end
    
	def change_script s
		s = make_absolute_path(s)
		make_app_js if compile_script(s)
	end
	
	def compile_manifest
		body = get_manifest_body
		return if @manifest_body == body
			
		@manifest_body = body
		puts "\n\ncompiling\n"
				
        paths = @manifest_body.split(/\n/)#.reject {|p| p.match(/\.min.js/)}
        @manifest_files = {}
        
        #for each path in the manifest compile the script if there is no min file, 
        # and it's not a .min file already
        paths.each do |p|
	        full_path = make_absolute_path(p)
	        	        
	        if full_path.empty? #bomb when you couldn't find a file
		        puts "Error: could not find the file in the manifest '#{p}'"
		        exit(0);
		    else
		       	@manifest_files[full_path.to_sym] = nil # add the key so we know it's in manifest
			   	min_exists = File.exist?(full_path.gsub('.js','.min.js'))
			   	compile_script(full_path) if !min_exists # only compile when min file not found
		    end
	    end
	    
		make_app_js unless @manifest_files.empty?
	end
	
	private
	
	def to_min_script s
		s.to_s.gsub('.js','.min.js') # might be a sym
	end
	
	def get_manifest_body
		%x{touch ./manifest.txt}
		read_body('manifest.txt')
	end
	
	def make_app_js
		contents = ''
		@manifest_files.each do |(key,value)|
			min_path = key.to_s.include?('.min.js') ? key : to_min_script(key)
			contents << "\n\n" + read_body(min_path).strip
		end
		%x{touch ./app.min.js}
		app_path = %x{ls $PWD/app.min.js}.gsub(/\n/, "")
		File.write(app_path, contents)
		puts "Wrote #{app_path} with #{@manifest_files.size} files."
	end
	
	def compile_script script
		compiled = nil
		in_manifest = @manifest_files.has_key?(script.to_sym)
		if !script.include?('.min.js') && in_manifest
			compiled = read_body script
			@manifest_files[script.to_sym] = compiled
			min_script = to_min_script(script)
            begin
	            puts "Compressing #{script}\n"
	            set_output_red #set output to red in case this fails
                minified =  @cpressor.compress(compiled)
                set_output_white
                puts "Creating the minified file: #{min_script}"
			    File.write(min_script, minified)
            rescue Exception => e
            	puts "** PROBLEM COMPRESSING #{script} SEE ABOVE ERROR."
            	File.write(min_script, compiled)
            ensure
                set_output_white
            end
		elsif in_manifest
		    #puts "File is already minifed and will be added: #{script}"
			compiled = read_body script
			@manifest_files[script.to_sym] = compiled
		end
		compiled
	end
	
	def set_output_red
		%x{$(tput setaf 1)}
	end
	
	def set_output_white
		%x{$(tput setaf 7)}
	end
	
	def make_absolute_path p
		abs_path = ''
	    abs_path = %x{ls $PWD/#{p}}.gsub(/\n/, "") unless p == 'min.js'
	    abs_path
	end
		
	def read_body filename
		%x{cat #{filename}}
		#File.open(filename, "rb") {|io| io.read}
	end
end

if ARGV[1].nil? || ARGV[1].empty?
	puts "Error: You need to specify a path for the watcher to find js in " + 
	     "i.e. /var/www/ben.pmdev.us/code/purplestrategies.com/wp-content/themes/main/js"
	exit(0);
end
base = ARGV[1].strip

begin
	Dir.chdir base
	exp = Regexp.new "(?!.*\.min\.js$).*\.js"
	c = Compressor.new(self)
	watch(exp) { |m| c.change_script(m[0]) }
rescue Errno::ENOENT => e
	puts "Error: Watch directory '#{base}' couldn't be found. Please use a valid directory"
	exit(0)
end
