import sys
#from contextlib import nested
#with nested(open(filein), open(fileout, 'w')) as (f, o):
#fileins = ["rpkm.4.txt", "rpkm.5.txt"]
#fileout = "test.txt"

def iter_format_file(filein):
    with open(filein) as f:
        yield(next(f))
        for l in f:
            d = l.rstrip("\n").split()
            name = d[0]
            datas = [float(i) for i in d[1:]]
            rdatas = []
            for i in datas:
                if i == 0:
                    rdatas.append("0")
                else:
                    rdatas.append('{:.2f}'.format(i))
            yield((name, rdatas))

def format2new_file(filein, fileout):
    with open(fileout, 'w') as o:
        f = iter_format_file(filein)
        o.write(next(f))
        for name, datas in f:
            o.write(name + "\t" + "\t".join(datas) + "\n")

def format2dict(header,filein,data_dict, i=0, str_flag=True):
    f = iter_format_file(filein)
    new_header = next(f).rstrip("\n")
    header_split = new_header.split("\t")
    sample_nums = len(header_split) - 1
    if not header:
        header = new_header
    else:
        header += "\t" + "\t".join(header_split[1:])
    for name, datas in f:
        if name not in data_dict:
            if str_flag:
                data_dict[name] = '\t'.join(["0"] * i)
            else:
                data_dict[name] = ["0"] * i
        if str_flag:
            if data_dict[name]: data_dict[name] += "\t"
            data_dict[name] += '\t'.join(datas)
        else:
            data_dict[name].extend(datas)
    i += sample_nums
    return(header, i)

def write2file(header, data_dict, fileout):
    with open(fileout, 'w') as o:
        o.write(header + "\n")
        names = sorted(data_dict.keys())
        for name in names:
            data = data_dict[name]
            o.write(name + "\t" + data + "\n")

def merge_all_file2file(fileins, fileout):  
    i = 0
    header = ""
    data_dict = {}
    for filein in fileins:
        header, i = format2dict(header, filein, data_dict, i)
    write2file(header, data_dict, fileout)

def main():
    import sys
    fileout = sys.argv[1]
    fileins = sys.argv[2:]
    merge_all_file2file(fileins, fileout)
    
if __name__ == "__main__":
    main()
