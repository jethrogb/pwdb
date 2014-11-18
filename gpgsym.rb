module GPGSymmetric
private
	Cmd=['gpg']
	DefaultOpts=%w(--no-use-agent --passphrase-fd 3 --batch --output - -- -)
	
	def self.run(options,stdin,fd3in)
		fd0r,fd0w=IO.pipe
		fd1r,fd1w=IO.pipe
		fd3r,fd3w=IO.pipe
		begin
			# Use /dev/null for fd 2, because gpg complains on fd 1 if fd 2 is closed
			pid=spawn(*(Cmd+options+DefaultOpts),0=>fd0r,1=>fd1w,2=>"/dev/null",3=>fd3r)
			fd0r.close
			fd1w.close
			fd3r.close

			fd3w.write(fd3in)
			fd3w.close
			fd3w=nil

			fd0w.write(stdin)
			fd0w.close
			fd0w=nil

			result=fd1r.read
			fd1r.close
			fd1r=nil

			Process.wait(pid)
			ret=$?.exited? ? $?.exitstatus : nil
		ensure
			fd0w.close unless fd0w.nil?
			fd3w.close unless fd3w.nil?
			fd1r.close unless fd1r.nil?
		end
		return result if ret==0
		return nil
	end
	
public
	def self.encrypt(plaintext,pass)
		encrypt_opts=%w(--symmetric --s2k-mode 3 --s2k-cipher-algo AES --cipher-algo AES --s2k-digest-algo SHA256 --digest-algo SHA256)
		run(encrypt_opts,plaintext,pass)
	end
	
	def self.decrypt(ciphertext,pass)
		run(%w(--decrypt),ciphertext,pass)
	end
end
