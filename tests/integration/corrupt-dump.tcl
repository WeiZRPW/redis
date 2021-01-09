# tests of corrupt ziplist payload with valid CRC
# * setting crash-memcheck-enabled to no to avoid issues with valgrind
# * setting use-exit-on-panic to yes so that valgrind can search for leaks
# * settng debug set-skip-checksum-validation to 1 on some tests for which we
#   didn't bother to fake a valid checksum
# * some tests set sanitize-dump-payload to no and some to yet, depending on
#   what we want to test

tags {"dump" "corruption"} {

set corrupt_payload_7445 "\x0E\x01\x1D\x1D\x00\x00\x00\x16\x00\x00\x00\x03\x00\x00\x04\x43\x43\x43\x43\x06\x04\x42\x42\x42\x42\x06\x3F\x41\x41\x41\x41\xFF\x09\x00\x88\xA5\xCA\xA8\xC5\x41\xF4\x35"

test {corrupt payload: #7445 - with sanitize} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        catch {
            r restore key 0 $corrupt_payload_7445
        } err
        assert_match "*Bad data format*" $err
        verify_log_message 0 "*integrity check failed*" 0
    }
}

test {corrupt payload: #7445 - without sanitize - 1} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r restore key 0 $corrupt_payload_7445
        catch {r lindex key 2}
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: #7445 - without sanitize - 2} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r restore key 0 $corrupt_payload_7445
        catch {r lset key 2 "BEEF"}
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: hash with valid zip list header, invalid entry len} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r restore key 0 "\x0D\x1B\x1B\x00\x00\x00\x16\x00\x00\x00\x04\x00\x00\x02\x61\x00\x04\x02\x62\x00\x04\x14\x63\x00\x04\x02\x64\x00\xFF\x09\x00\xD9\x10\x54\x92\x15\xF5\x5F\x52"
        r config set hash-max-ziplist-entries 1
        catch {r hset key b b}
        verify_log_message 0 "*zipEntrySafe*" 0
    }
}

test {corrupt payload: invalid zlbytes header} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        catch {
            r restore key 0 "\x0D\x1B\x25\x00\x00\x00\x16\x00\x00\x00\x04\x00\x00\x02\x61\x00\x04\x02\x62\x00\x04\x02\x63\x00\x04\x02\x64\x00\xFF\x09\x00\xB7\xF7\x6E\x9F\x43\x43\x14\xC6"
        } err
        assert_match "*Bad data format*" $err
    }
}

test {corrupt payload: valid zipped hash header, dup records} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r restore key 0 "\x0D\x1B\x1B\x00\x00\x00\x16\x00\x00\x00\x04\x00\x00\x02\x61\x00\x04\x02\x62\x00\x04\x02\x61\x00\x04\x02\x64\x00\xFF\x09\x00\xA1\x98\x36\x78\xCC\x8E\x93\x2E"
        r config set hash-max-ziplist-entries 1
        # cause an assertion when converting to hash table
        catch {r hset key b b}
        verify_log_message 0 "*ziplist with dup elements dump*" 0
    }
}

test {corrupt payload: quicklist big ziplist prev len} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r restore key 0 "\x0E\x01\x13\x13\x00\x00\x00\x0E\x00\x00\x00\x02\x00\x00\x02\x61\x00\x0E\x02\x62\x00\xFF\x09\x00\x49\x97\x30\xB2\x0D\xA1\xED\xAA"
        catch {r lindex key -2}
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: quicklist small ziplist prev len} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        catch {
            r restore key 0 "\x0E\x01\x13\x13\x00\x00\x00\x0E\x00\x00\x00\x02\x00\x00\x02\x61\x00\x02\x02\x62\x00\xFF\x09\x00\xC7\x71\x03\x97\x07\x75\xB0\x63"
        } err
        assert_match "*Bad data format*" $err
        verify_log_message 0 "*integrity check failed*" 0
    }
}

test {corrupt payload: quicklist ziplist wrong count} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r restore key 0 "\x0E\x01\x13\x13\x00\x00\x00\x0E\x00\x00\x00\x03\x00\x00\x02\x61\x00\x04\x02\x62\x00\xFF\x09\x00\x4D\xE2\x0A\x2F\x08\x25\xDF\x91"
        # we'll be able to push, but iterating on the list will assert
        r lpush key header
        r rpush key footer
        catch { [r lrange key -1 -1] }
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: #3080 - quicklist} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        catch {
            r RESTORE key 0 "\x0E\x01\x80\x00\x00\x00\x10\x41\x41\x41\x41\x41\x41\x41\x41\x02\x00\x00\x80\x41\x41\x41\x41\x07\x00\x03\xC7\x1D\xEF\x54\x68\xCC\xF3"
            r DUMP key ;# DUMP was used in the original issue, but now even with shallow sanitization restore safely fails, so this is dead code
        } err
        assert_match "*Bad data format*" $err
        verify_log_message 0 "*integrity check failed*" 0
    }
}

test {corrupt payload: #3080 - ziplist} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        # shallow sanitization is enough for restore to safely reject the payload with wrong size
        r config set sanitize-dump-payload no
        catch {
            r RESTORE key 0 "\x0A\x80\x00\x00\x00\x10\x41\x41\x41\x41\x41\x41\x41\x41\x02\x00\x00\x80\x41\x41\x41\x41\x07\x00\x39\x5B\x49\xE0\xC1\xC6\xDD\x76"
        } err
        assert_match "*Bad data format*" $err
        verify_log_message 0 "*integrity check failed*" 0
    }
}

test {corrupt payload: load corrupted rdb with no CRC - #3505} {
    set server_path [tmpdir "server.rdb-corruption-test"]
    exec cp tests/assets/corrupt_ziplist.rdb $server_path
    set srv [start_server [list overrides [list "dir" $server_path "dbfilename" "corrupt_ziplist.rdb" loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no sanitize-dump-payload no]]]

    # wait for termination
    wait_for_condition 100 50 {
        ! [is_alive $srv]
    } else {
        fail "rdb loading didn't fail"
    }

    set stdout [dict get $srv stdout]
    assert_equal [count_message_lines $stdout "Terminating server after rdb file reading failure."]  1
    assert_lessthan 1 [count_message_lines $stdout "integrity check failed"]
    kill_server $srv ;# let valgrind look for issues
}

test {corrupt payload: listpack invalid size header} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        catch {
            r restore key 0 "\x0F\x01\x10\x00\x00\x00\x00\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x02\x40\x55\x5F\x00\x00\x00\x0F\x00\x01\x01\x00\x01\x02\x01\x88\x31\x00\x00\x00\x00\x00\x00\x00\x09\x88\x32\x00\x00\x00\x00\x00\x00\x00\x09\x00\x01\x00\x01\x00\x01\x00\x01\x02\x02\x88\x31\x00\x00\x00\x00\x00\x00\x00\x09\x88\x61\x00\x00\x00\x00\x00\x00\x00\x09\x88\x32\x00\x00\x00\x00\x00\x00\x00\x09\x88\x62\x00\x00\x00\x00\x00\x00\x00\x09\x08\x01\xFF\x0A\x01\x00\x00\x09\x00\x45\x91\x0A\x87\x2F\xA5\xF9\x2E"
        } err
        assert_match "*Bad data format*" $err
        verify_log_message 0 "*Stream listpack integrity check failed*" 0
    }
}

test {corrupt payload: listpack too long entry len} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r restore key 0 "\x0F\x01\x10\x00\x00\x00\x00\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x02\x40\x55\x55\x00\x00\x00\x0F\x00\x01\x01\x00\x01\x02\x01\x88\x31\x00\x00\x00\x00\x00\x00\x00\x09\x88\x32\x00\x00\x00\x00\x00\x00\x00\x09\x00\x01\x00\x01\x00\x01\x00\x01\x02\x02\x89\x31\x00\x00\x00\x00\x00\x00\x00\x09\x88\x61\x00\x00\x00\x00\x00\x00\x00\x09\x88\x32\x00\x00\x00\x00\x00\x00\x00\x09\x88\x62\x00\x00\x00\x00\x00\x00\x00\x09\x08\x01\xFF\x0A\x01\x00\x00\x09\x00\x40\x63\xC9\x37\x03\xA2\xE5\x68"
        catch {
            r xinfo stream key full
        } err
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: listpack very long entry len} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r restore key 0 "\x0F\x01\x10\x00\x00\x00\x00\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x02\x40\x55\x55\x00\x00\x00\x0F\x00\x01\x01\x00\x01\x02\x01\x88\x31\x00\x00\x00\x00\x00\x00\x00\x09\x88\x32\x00\x00\x00\x00\x00\x00\x00\x09\x00\x01\x00\x01\x00\x01\x00\x01\x02\x02\x88\x31\x00\x00\x00\x00\x00\x00\x00\x09\x88\x61\x00\x00\x00\x00\x00\x00\x00\x09\x88\x32\x00\x00\x00\x00\x00\x00\x00\x09\x9C\x62\x00\x00\x00\x00\x00\x00\x00\x09\x08\x01\xFF\x0A\x01\x00\x00\x09\x00\x63\x6F\x42\x8E\x7C\xB5\xA2\x9D"
        catch {
            r xinfo stream key full
        } err
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: listpack too long entry prev len} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        catch {
            r restore key 0 "\x0F\x01\x10\x00\x00\x00\x00\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x02\x40\x55\x55\x00\x00\x00\x0F\x00\x01\x01\x00\x15\x02\x01\x88\x31\x00\x00\x00\x00\x00\x00\x00\x09\x88\x32\x00\x00\x00\x00\x00\x00\x00\x09\x00\x01\x00\x01\x00\x01\x00\x01\x02\x02\x88\x31\x00\x00\x00\x00\x00\x00\x00\x09\x88\x61\x00\x00\x00\x00\x00\x00\x00\x09\x88\x32\x00\x00\x00\x00\x00\x00\x00\x09\x88\x62\x00\x00\x00\x00\x00\x00\x00\x09\x08\x01\xFF\x0A\x01\x00\x00\x09\x00\x06\xFB\x44\x24\x0A\x8E\x75\xEA"
        } err
        assert_match "*Bad data format*" $err
        verify_log_message 0 "*Stream listpack integrity check failed*" 0
    }
}

test {corrupt payload: hash ziplist with duplicate records} {
    # when we do perform full sanitization, we expect duplicate records to fail the restore
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        r debug set-skip-checksum-validation 1
        catch { r RESTORE _hash 0 "\x0D\x3D\x3D\x00\x00\x00\x3A\x00\x00\x00\x14\x13\x00\xF5\x02\xF5\x02\xF2\x02\x53\x5F\x31\x04\xF3\x02\xF3\x02\xF7\x02\xF7\x02\xF8\x02\x02\x5F\x37\x04\xF1\x02\xF1\x02\xF6\x02\x02\x5F\x35\x04\xF4\x02\x02\x5F\x33\x04\xFA\x02\x02\x5F\x39\x04\xF9\x02\xF9\xFF\x09\x00\xB5\x48\xDE\x62\x31\xD0\xE5\x63" } err
        assert_match "*Bad data format*" $err
    }
}

test {corrupt payload: hash ziplist uneven record count} {
    # when we do perform full sanitization, we expect duplicate records to fail the restore
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        r debug set-skip-checksum-validation 1
        catch { r RESTORE _hash 0 "\r\x1b\x1b\x00\x00\x00\x16\x00\x00\x00\x04\x00\x00\x02a\x00\x04\x02b\x00\x04\x02a\x00\x04\x02d\x00\xff\t\x00\xa1\x98\x36x\xcc\x8e\x93\x2e" } err
        assert_match "*Bad data format*" $err
    }
}

test {corrupt payload: hash dupliacte records} {
    # when we do perform full sanitization, we expect duplicate records to fail the restore
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        r debug set-skip-checksum-validation 1
        catch { r RESTORE _hash 0 "\x04\x02\x01a\x01b\x01a\x01d\t\x00\xc6\x9c\xab\xbc\bk\x0c\x06" } err
        assert_match "*Bad data format*" $err
    }
}

test {corrupt payload: fuzzer findings - NPD in streamIteratorGetID} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        catch {
            r RESTORE key 0 "\x0F\x01\x10\x00\x00\x01\x73\xBD\x68\x48\x71\x00\x00\x00\x00\x00\x00\x00\x00\x40\x42\x42\x00\x00\x00\x18\x00\x03\x01\x00\x01\x02\x01\x84\x69\x74\x65\x6D\x05\x85\x76\x61\x6C\x75\x65\x06\x00\x01\x02\x01\x00\x01\x00\x01\x01\x01\x00\x01\x05\x01\x02\x01\x00\x01\x01\x01\x01\x01\x82\x5F\x31\x03\x05\x01\x02\x01\x00\x01\x02\x01\x01\x01\x02\x01\x48\x01\xFF\x03\x81\x00\x00\x01\x73\xBD\x68\x48\x71\x02\x01\x07\x6D\x79\x67\x72\x6F\x75\x70\x81\x00\x00\x01\x73\xBD\x68\x48\x71\x00\x01\x00\x00\x01\x73\xBD\x68\x48\x71\x00\x00\x00\x00\x00\x00\x00\x00\x72\x48\x68\xBD\x73\x01\x00\x00\x01\x01\x05\x41\x6C\x69\x63\x65\x72\x48\x68\xBD\x73\x01\x00\x00\x01\x00\x00\x01\x73\xBD\x68\x48\x71\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00\x80\xCD\xB0\xD5\x1A\xCE\xFF\x10"
            r XREVRANGE key 725 233
        }
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: fuzzer findings - listpack NPD on invalid stream} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        catch {
            r RESTORE _stream 0 "\x0F\x01\x10\x00\x00\x01\x73\xDC\xB6\x6B\xF1\x00\x00\x00\x00\x00\x00\x00\x00\x40\x42\x42\x00\x00\x00\x18\x00\x03\x01\x00\x01\x02\x01\x84\x69\x74\x65\x6D\x05\x85\x76\x61\x6C\x75\x65\x06\x00\x01\x02\x01\x00\x01\x00\x01\x01\x01\x00\x01\x05\x01\x02\x01\x1F\x01\x00\x01\x01\x01\x6D\x5F\x31\x03\x05\x01\x02\x01\x29\x01\x00\x01\x01\x01\x02\x01\x05\x01\xFF\x03\x81\x00\x00\x01\x73\xDC\xB6\x6C\x1A\x00\x01\x07\x6D\x79\x67\x72\x6F\x75\x70\x81\x00\x00\x01\x73\xDC\xB6\x6B\xF1\x00\x01\x00\x00\x01\x73\xDC\xB6\x6B\xF1\x00\x00\x00\x00\x00\x00\x00\x00\x4B\x6C\xB6\xDC\x73\x01\x00\x00\x01\x01\x05\x41\x6C\x69\x63\x65\x3D\x6C\xB6\xDC\x73\x01\x00\x00\x01\x00\x00\x01\x73\xDC\xB6\x6B\xF1\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00\xC7\x7D\x1C\xD7\x04\xFF\xE6\x9D"
            r XREAD STREAMS _stream 519389898758
        }
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: fuzzer findings - NPD in quicklistIndex} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        catch {
            r RESTORE key 0 "\x0E\x01\x13\x13\x00\x00\x00\x10\x00\x00\x00\x03\x12\x00\xF3\x02\x02\x5F\x31\x04\xF1\xFF\x09\x00\xC9\x4B\x31\xFE\x61\xC0\x96\xFE"
            r LSET key 290 290
        }
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: fuzzer findings - invalid read in ziplistFind} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        catch {
            r RESTORE key 0 "\x0D\x19\x19\x00\x00\x00\x16\x00\x00\x00\x06\x00\x00\xF1\x02\xF1\x02\xF2\x02\x02\x5F\x31\x04\x99\x02\xF3\xFF\x09\x00\xC5\xB8\x10\xC0\x8A\xF9\x16\xDF"
            r HEXISTS key -688319650333
        }
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}


test {corrupt payload: fuzzer findings - invalid ziplist encoding} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        r debug set-skip-checksum-validation 1
        catch {
            r RESTORE _listbig 0 "\x0E\x02\x1B\x1B\x00\x00\x00\x16\x00\x00\x00\x05\x00\x00\x02\x5F\x39\x04\xF9\x02\x86\x5F\x37\x04\xF7\x02\x02\x5F\x35\xFF\x19\x19\x00\x00\x00\x16\x00\x00\x00\x05\x00\x00\xF5\x02\x02\x5F\x33\x04\xF3\x02\x02\x5F\x31\x04\xF1\xFF\x09\x00\x0C\xFC\x99\x2C\x23\x45\x15\x60"
        } err
        assert_match "*Bad data format*" $err
        verify_log_message 0 "*integrity check failed*" 0
    }
}

test {corrupt payload: fuzzer findings - hash crash} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        r debug set-skip-checksum-validation 1
        r RESTORE _hash 0 "\x0D\x19\x19\x00\x00\x00\x16\x00\x00\x00\x06\x00\x00\xF1\x02\xF1\x02\xF2\x02\x02\x5F\x31\x04\xF3\x02\xF3\xFF\x09\x00\x38\xB8\x10\xC0\x8A\xF9\x16\xDF"
        r HSET _hash 394891450 1635910264
        r HMGET _hash 887312884855
    }
}

test {corrupt payload: fuzzer findings - uneven entry count in hash} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        r RESTORE _hashbig 0 "\x0D\x3D\x3D\x00\x00\x00\x38\x00\x00\x00\x14\x00\x00\xF2\x02\x02\x5F\x31\x04\x1C\x02\xF7\x02\xF1\x02\xF1\x02\xF5\x02\xF5\x02\xF4\x02\x02\x5F\x33\x04\xF6\x02\x02\x5F\x35\x04\xF8\x02\x02\x5F\x37\x04\xF9\x02\xF9\x02\xF3\x02\xF3\x02\xFA\x02\x02\x5F\x39\xFF\x09\x00\x73\xB7\x68\xC8\x97\x24\x8E\x88"
        catch { r HSCAN _hashbig -250 }
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: fuzzer findings - invalid read in lzf_decompress} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        catch { r RESTORE _setbig 0 "\x02\x03\x02\x5F\x31\xC0\x02\xC3\x00\x09\x00\xE6\xDC\x76\x44\xFF\xEB\x3D\xFE" } err
        assert_match "*Bad data format*" $err
    }
}

test {corrupt payload: fuzzer findings - leak in rdbloading due to dup entry in set} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        catch { r RESTORE _setbig 0 "\x02\x0A\x02\x5F\x39\xC0\x06\x02\x5F\x31\xC0\x00\xC0\x04\x02\x5F\x35\xC0\x02\xC0\x08\x02\x5F\x31\x02\x5F\x33\x09\x00\x7A\x5A\xFB\x90\x3A\xE9\x3C\xBE" } err
        assert_match "*Bad data format*" $err
    }
}

test {corrupt payload: fuzzer findings - empty intset div by zero} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        r RESTORE _setbig 0 "\x02\xC0\xC0\x06\x02\x5F\x39\xC0\x02\x02\x5F\x33\xC0\x00\x02\x5F\x31\xC0\x04\xC0\x08\x02\x5F\x37\x02\x5F\x35\x09\x00\xC5\xD4\x6D\xBA\xAD\x14\xB7\xE7"
        catch {r SRANDMEMBER _setbig }
    }
}

test {corrupt payload: fuzzer findings - valgrind ziplist - crash report prints freed memory} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        r RESTORE _zsetbig 0 "\x0C\x3D\x3D\x00\x00\x00\x3A\x00\x00\x00\x14\x00\x00\xF1\x02\xF1\x02\x02\x5F\x31\x04\xF2\x02\xF3\x02\xF3\x02\x02\x5F\x33\x04\xF4\x02\xEE\x02\xF5\x02\x02\x5F\x35\x04\xF6\x02\xF7\x02\xF7\x02\x02\x5F\x37\x04\xF8\x02\xF9\x02\xF9\x02\x02\x5F\x39\x04\xFA\xFF\x09\x00\xAE\xF9\x77\x2A\x47\x24\x33\xF6"
        catch { r ZREMRANGEBYSCORE _zsetbig -1050966020 724 }
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: fuzzer findings - valgrind ziplist prevlen reaches outside the ziplist} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        r RESTORE _listbig 0 "\x0E\x02\x1B\x1B\x00\x00\x00\x16\x00\x00\x00\x05\x00\x00\x02\x5F\x39\x04\xF9\x02\x02\x5F\x37\x04\xF7\x02\x02\x5F\x35\xFF\x19\x19\x00\x00\x00\x16\x00\x00\x00\x05\x00\x00\xF5\x02\x02\x5F\x33\x04\xF3\x95\x02\x5F\x31\x04\xF1\xFF\x09\x00\x0C\xFC\x99\x2C\x23\x45\x15\x60"
        catch { r RPOP _listbig }
        catch { r RPOP _listbig }
        catch { r RPUSH _listbig 949682325 }
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: fuzzer findings - valgrind - bad rdbLoadDoubleValue} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        catch { r RESTORE _list 0 "\x03\x01\x11\x11\x00\x00\x00\x0A\x00\x00\x00\x01\x00\x00\xD0\x07\x1A\xE9\x02\xFF\x09\x00\x1A\x06\x07\x32\x41\x28\x3A\x46" } err
        assert_match "*Bad data format*" $err
    }
}

test {corrupt payload: fuzzer findings - valgrind ziplist prev too big} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        r RESTORE _list 0 "\x0E\x01\x13\x13\x00\x00\x00\x10\x00\x00\x00\x03\x00\x00\xF3\x02\x02\x5F\x31\xC1\xF1\xFF\x09\x00\xC9\x4B\x31\xFE\x61\xC0\x96\xFE"
        catch { r RPUSHX _list -45 }
        catch { r LREM _list -748 -840}
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: fuzzer findings - lzf decompression fails, avoid valgrind invalid read} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        catch {r RESTORE _stream 0 "\x0F\x02\x10\x00\x00\x01\x73\xDD\xAA\x2A\xB9\x00\x00\x00\x00\x00\x00\x00\x00\xC3\x40\x4B\x40\x5C\x18\x5C\x00\x00\x00\x24\x00\x05\x01\x00\x01\x02\x01\x84\x69\x74\x65\x6D\x05\x85\x76\x61\x6C\x75\x65\x06\x40\x10\x00\x00\x20\x01\x00\x01\x20\x03\x00\x05\x20\x1C\x40\x07\x05\x01\x01\x82\x5F\x31\x03\x80\x0D\x40\x00\x00\x02\x60\x19\x40\x27\x40\x19\x00\x33\x60\x19\x40\x29\x02\x01\x01\x04\x20\x19\x00\xFF\x10\x00\x00\x01\x73\xDD\xAA\x2A\xBC\x00\x00\x00\x00\x00\x00\x00\x00\xC3\x40\x4D\x40\x5E\x18\x5E\x00\x00\x00\x24\x00\x05\x01\x00\x01\x02\x01\x84\x69\x74\x65\x6D\x05\x85\x76\x61\x6C\x75\x65\x06\x40\x10\x00\x00\x20\x01\x06\x01\x01\x82\x5F\x35\x03\x05\x20\x1E\x17\x0B\x03\x01\x01\x06\x01\x40\x0B\x00\x01\x60\x0D\x02\x82\x5F\x37\x60\x19\x80\x00\x00\x08\x60\x19\x80\x27\x02\x82\x5F\x39\x20\x19\x00\xFF\x0A\x81\x00\x00\x01\x73\xDD\xAA\x2A\xBE\x00\x00\x09\x00\x21\x85\x77\x43\x71\x7B\x17\x88"} err
        assert_match "*Bad data format*" $err
    }
}

test {corrupt payload: fuzzer findings - stream bad lp_count} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        r debug set-skip-checksum-validation 1
        catch { r RESTORE _stream 0 "\x0F\x01\x10\x00\x00\x01\x73\xDE\xDF\x7D\x9B\x00\x00\x00\x00\x00\x00\x00\x00\x40\x42\x42\x00\x00\x00\x18\x00\x03\x01\x00\x01\x02\x01\x84\x69\x74\x65\x6D\x05\x85\x76\x61\x6C\x75\x65\x06\x00\x01\x02\x01\x00\x01\x00\x01\x01\x01\x00\x01\x56\x01\x02\x01\x22\x01\x00\x01\x01\x01\x82\x5F\x31\x03\x05\x01\x02\x01\x2C\x01\x00\x01\x01\x01\x02\x01\x05\x01\xFF\x03\x81\x00\x00\x01\x73\xDE\xDF\x7D\xC7\x00\x01\x07\x6D\x79\x67\x72\x6F\x75\x70\x81\x00\x00\x01\x73\xDE\xDF\x7D\x9B\x00\x01\x00\x00\x01\x73\xDE\xDF\x7D\x9B\x00\x00\x00\x00\x00\x00\x00\x00\xF9\x7D\xDF\xDE\x73\x01\x00\x00\x01\x01\x05\x41\x6C\x69\x63\x65\xEB\x7D\xDF\xDE\x73\x01\x00\x00\x01\x00\x00\x01\x73\xDE\xDF\x7D\x9B\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00\xB2\xA8\xA7\x5F\x1B\x61\x72\xD5"} err
        assert_match "*Bad data format*" $err
        r ping
    }
}

test {corrupt payload: fuzzer findings - stream bad lp_count - unsanitized} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        r RESTORE _stream 0 "\x0F\x01\x10\x00\x00\x01\x73\xDE\xDF\x7D\x9B\x00\x00\x00\x00\x00\x00\x00\x00\x40\x42\x42\x00\x00\x00\x18\x00\x03\x01\x00\x01\x02\x01\x84\x69\x74\x65\x6D\x05\x85\x76\x61\x6C\x75\x65\x06\x00\x01\x02\x01\x00\x01\x00\x01\x01\x01\x00\x01\x56\x01\x02\x01\x22\x01\x00\x01\x01\x01\x82\x5F\x31\x03\x05\x01\x02\x01\x2C\x01\x00\x01\x01\x01\x02\x01\x05\x01\xFF\x03\x81\x00\x00\x01\x73\xDE\xDF\x7D\xC7\x00\x01\x07\x6D\x79\x67\x72\x6F\x75\x70\x81\x00\x00\x01\x73\xDE\xDF\x7D\x9B\x00\x01\x00\x00\x01\x73\xDE\xDF\x7D\x9B\x00\x00\x00\x00\x00\x00\x00\x00\xF9\x7D\xDF\xDE\x73\x01\x00\x00\x01\x01\x05\x41\x6C\x69\x63\x65\xEB\x7D\xDF\xDE\x73\x01\x00\x00\x01\x00\x00\x01\x73\xDE\xDF\x7D\x9B\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00\xB2\xA8\xA7\x5F\x1B\x61\x72\xD5"
        catch { r XREVRANGE _stream 638932639 738}
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: fuzzer findings - stream integrity check issue} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        r debug set-skip-checksum-validation 1
        catch { r RESTORE _stream 0 "\x0F\x02\x10\x00\x00\x01\x75\x2D\xA2\x90\x67\x00\x00\x00\x00\x00\x00\x00\x00\xC3\x40\x4F\x40\x5C\x18\x5C\x00\x00\x00\x24\x00\x05\x01\x00\x01\x4A\x01\x84\x69\x74\x65\x6D\x05\x85\x76\x61\x6C\x75\x65\x06\x40\x10\x00\x00\x20\x01\x00\x01\x20\x03\x00\x05\x20\x1C\x40\x09\x05\x01\x01\x82\x5F\x31\x03\x80\x0D\x00\x02\x20\x0D\x00\x02\xA0\x19\x00\x03\x20\x0B\x02\x82\x5F\x33\xA0\x19\x00\x04\x20\x0D\x00\x04\x20\x19\x00\xFF\x10\x00\x00\x01\x75\x2D\xA2\x90\x67\x00\x00\x00\x00\x00\x00\x00\x05\xC3\x40\x56\x40\x60\x18\x60\x00\x00\x00\x24\x00\x05\x01\x00\x01\x02\x01\x84\x69\x74\x65\x6D\x05\x85\x76\x61\x6C\x75\x65\x06\x40\x10\x00\x00\x20\x01\x06\x01\x01\x82\x5F\x35\x03\x05\x20\x1E\x40\x0B\x03\x01\x01\x06\x01\x80\x0B\x00\x02\x20\x0B\x02\x82\x5F\x37\x60\x19\x03\x01\x01\xDF\xFB\x20\x05\x00\x08\x60\x1A\x20\x0C\x00\xFC\x20\x05\x02\x82\x5F\x39\x20\x1B\x00\xFF\x0A\x81\x00\x00\x01\x75\x2D\xA2\x90\x68\x01\x00\x09\x00\x1D\x6F\xC0\x69\x8A\xDE\xF7\x92" } err
        assert_match "*Bad data format*" $err
    }
}

test {corrupt payload: fuzzer findings - infinite loop} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        r RESTORE _stream 0 "\x0F\x01\x10\x00\x00\x01\x75\x3A\xA6\xD0\x93\x00\x00\x00\x00\x00\x00\x00\x00\x40\x42\x42\x00\x00\x00\x18\x00\x03\x01\x00\x01\x02\x01\x84\x69\x74\x65\x6D\x05\x85\x76\x61\x6C\x75\x65\x06\x00\x01\x02\x01\x00\x01\x00\x01\x01\x01\x00\x01\x05\x01\x02\x01\x00\x01\x01\x01\x01\x01\x82\x5F\x31\x03\xFD\x01\x02\x01\x00\x01\x02\x01\x01\x01\x02\x01\x05\x01\xFF\x03\x81\x00\x00\x01\x75\x3A\xA6\xD0\x93\x02\x01\x07\x6D\x79\x67\x72\x6F\x75\x70\x81\x00\x00\x01\x75\x3A\xA6\xD0\x93\x00\x01\x00\x00\x01\x75\x3A\xA6\xD0\x93\x00\x00\x00\x00\x00\x00\x00\x00\x94\xD0\xA6\x3A\x75\x01\x00\x00\x01\x01\x05\x41\x6C\x69\x63\x65\x94\xD0\xA6\x3A\x75\x01\x00\x00\x01\x00\x00\x01\x75\x3A\xA6\xD0\x93\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00\xC4\x09\xAD\x69\x7E\xEE\xA6\x2F"
        catch { r XREVRANGE _stream 288270516 971031845 }
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: fuzzer findings - hash convert asserts on RESTORE with shallow sanitization} {
    # if we don't perform full sanitization, and the next command can assert on converting
    # a ziplist to hash records, then we're ok with that happning in RESTORE too
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        catch { r RESTORE _hash 0 "\x0D\x3D\x3D\x00\x00\x00\x3A\x00\x00\x00\x14\x13\x00\xF5\x02\xF5\x02\xF2\x02\x53\x5F\x31\x04\xF3\x02\xF3\x02\xF7\x02\xF7\x02\xF8\x02\x02\x5F\x37\x04\xF1\x02\xF1\x02\xF6\x02\x02\x5F\x35\x04\xF4\x02\x02\x5F\x33\x04\xFA\x02\x02\x5F\x39\x04\xF9\x02\xF9\xFF\x09\x00\xB5\x48\xDE\x62\x31\xD0\xE5\x63" }
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: OOM in rdbGenericLoadStringObject} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        catch { r RESTORE x 0 "\x0A\x81\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x13\x00\x00\x00\x0E\x00\x00\x00\x02\x00\x00\x02\x61\x00\x04\x02\x62\x00\xFF\x09\x00\x57\x04\xE5\xCD\xD4\x37\x6C\x57" } err
        assert_match "*Bad data format*" $err
        r ping
    }
}

test {corrupt payload: fuzzer findings - OOM in dictExpand} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        catch { r RESTORE x 0 "\x02\x81\x02\x5F\x31\xC0\x00\xC0\x02\x09\x00\xCD\x84\x2C\xB7\xE8\xA4\x49\x57" } err
        assert_match "*Bad data format*" $err
        r ping
    }
}

test {corrupt payload: fuzzer findings - invalid tail offset after removal} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        r RESTORE _zset 0 "\x0C\x19\x19\x00\x00\x00\x02\x00\x00\x00\x06\x00\x00\xF1\x02\xF1\x02\x02\x5F\x31\x04\xF2\x02\xF3\x02\xF3\xFF\x09\x00\x4D\x72\x7B\x97\xCD\x9A\x70\xC1"
        catch {r ZPOPMIN _zset}
        catch {r ZPOPMAX _zset}
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: fuzzer findings - negative reply length} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload no
        r debug set-skip-checksum-validation 1
        r RESTORE _stream 0 "\x0F\x01\x10\x00\x00\x01\x75\xCF\xA1\x16\xA7\x00\x00\x00\x00\x00\x00\x00\x00\x40\x42\x42\x00\x00\x00\x18\x00\x03\x01\x00\x01\x02\x01\x84\x69\x74\x65\x6D\x05\x85\x76\x61\x6C\x75\x65\x06\x00\x01\x02\x01\x00\x01\x00\x01\x01\x01\x00\x01\x05\x01\x02\x01\x00\x01\x01\x01\x01\x01\x14\x5F\x31\x03\x05\x01\x02\x01\x00\x01\x02\x01\x01\x01\x02\x01\x05\x01\xFF\x03\x81\x00\x00\x01\x75\xCF\xA1\x16\xA7\x02\x01\x07\x6D\x79\x67\x72\x6F\x75\x70\x81\x00\x00\x01\x75\xCF\xA1\x16\xA7\x01\x01\x00\x00\x01\x75\xCF\xA1\x16\xA7\x00\x00\x00\x00\x00\x00\x00\x01\xA7\x16\xA1\xCF\x75\x01\x00\x00\x01\x01\x05\x41\x6C\x69\x63\x65\xA7\x16\xA1\xCF\x75\x01\x00\x00\x01\x00\x00\x01\x75\xCF\xA1\x16\xA7\x00\x00\x00\x00\x00\x00\x00\x01\x09\x00\x1B\x42\x52\xB8\xDD\x5C\xE5\x4E"
        catch {r XADD _stream * -956 -2601503852}
        catch {r XINFO STREAM _stream FULL}
        assert_equal [count_log_message 0 "crashed by signal"] 0
        assert_equal [count_log_message 0 "ASSERTION FAILED"] 1
    }
}

test {corrupt payload: fuzzer findings - valgrind negative malloc} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        r debug set-skip-checksum-validation 1
        catch {r RESTORE _key 0 "\x0E\x01\x81\xD6\xD6\x00\x00\x00\x0A\x00\x00\x00\x01\x00\x00\x40\xC8\x6F\x2F\x36\xE2\xDF\xE3\x2E\x26\x64\x8B\x87\xD1\x7A\xBD\xFF\xEF\xEF\x63\x65\xF6\xF8\x8C\x4E\xEC\x96\x89\x56\x88\xF8\x3D\x96\x5A\x32\xBD\xD1\x36\xD8\x02\xE6\x66\x37\xCB\x34\x34\xC4\x52\xA7\x2A\xD5\x6F\x2F\x7E\xEE\xA2\x94\xD9\xEB\xA9\x09\x38\x3B\xE1\xA9\x60\xB6\x4E\x09\x44\x1F\x70\x24\xAA\x47\xA8\x6E\x30\xE1\x13\x49\x4E\xA1\x92\xC4\x6C\xF0\x35\x83\xD9\x4F\xD9\x9C\x0A\x0D\x7A\xE7\xB1\x61\xF5\xC1\x2D\xDC\xC3\x0E\x87\xA6\x80\x15\x18\xBA\x7F\x72\xDD\x14\x75\x46\x44\x0B\xCA\x9C\x8F\x1C\x3C\xD7\xDA\x06\x62\x18\x7E\x15\x17\x24\xAB\x45\x21\x27\xC2\xBC\xBB\x86\x6E\xD8\xBD\x8E\x50\xE0\xE0\x88\xA4\x9B\x9D\x15\x2A\x98\xFF\x5E\x78\x6C\x81\xFC\xA8\xC9\xC8\xE6\x61\xC8\xD1\x4A\x7F\x81\xD6\xA6\x1A\xAD\x4C\xC1\xA2\x1C\x90\x68\x15\x2A\x8A\x36\xC0\x58\xC3\xCC\xA6\x54\x19\x12\x0F\xEB\x46\xFF\x6E\xE3\xA7\x92\xF8\xFF\x09\x00\xD0\x71\xF7\x9F\xF7\x6A\xD6\x2E"} err
        assert_match "*Bad data format*" $err
        r ping
    }
}

test {corrupt payload: fuzzer findings - valgrind invalid read} {
    start_server [list overrides [list loglevel verbose use-exit-on-panic yes crash-memcheck-enabled no] ] {
        r config set sanitize-dump-payload yes
        r debug set-skip-checksum-validation 1
        catch {r RESTORE _key 0 "\x05\x0A\x02\x5F\x39\x00\x00\x00\x00\x00\x00\x22\x40\xC0\x08\x00\x00\x00\x00\x00\x00\x20\x40\x02\x5F\x37\x00\x00\x00\x00\x00\x00\x1C\x40\xC0\x06\x00\x00\x00\x00\x00\x00\x18\x40\x02\x5F\x33\x00\x00\x00\x00\x00\x00\x14\x40\xC0\x04\x00\x00\x00\x00\x00\x00\x10\x40\x02\x5F\x33\x00\x00\x00\x00\x00\x00\x08\x40\xC0\x02\x00\x00\x00\x00\x00\x00\x00\x40\x02\x5F\x31\x00\x00\x00\x00\x00\x00\xF0\x3F\xC0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x09\x00\x3C\x66\xD7\x14\xA9\xDA\x3C\x69"} err
        assert_match "*Bad data format*" $err
        r ping
    }
}

} ;# tags

