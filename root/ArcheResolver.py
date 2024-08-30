
class ArcheResolver(SimpleHTTPResolver):
    """
    Specialization of the SimpleHTTPResolver capable of accessing selected
    instance data directly on a disk.
    """
    def __init__(self, config):
        super(ArcheResolver, self).__init__(config)
        self.arche_storage_dir = self.config['arche_storage_dir']
        self.arche_storage_depth = int(self.config['arche_storage_depth'])
        self.arche_base_url = self.config['arche_base_url']
        self.allowed_locations = self.config['allowed_locations']
        self.unauthorized_image = self.config['unauthorized_image']

    def _get_arche_path(self, id):
        path = self.arche_storage_dir
        n = self.arche_storage_depth
        id2 = int(id)
        while (n > 0):
            path = join(path, '{:02d}'.format(id2 % 100))
            id2 = int(id2 / 100)
            n -= 1
        return join(path, str(id))

    def _get_file_format(self, fp):
        fph = open(fp, 'rb')
        signature = fph.read(4)
        signatureInt = int.from_bytes(signature, 'big')
        if int.from_bytes(signature[0:2], 'big') == int(0xFFD8):
            return 'jpg'
        if signatureInt == int(0x49492A00) or signatureInt == int(0x4D4D002A):
            return 'tif'
        if signatureInt == int(0x89504E47):
            return 'png'
        if signatureInt == int(0x0000000C):
            return 'jp2'
        if signatureInt == int(0x52494646):
            return 'webp'
        if signatureInt == int(0x47494638):
            return 'gif'
        raise ResolverException('Unknown image format')

    def is_resolvable(self, ident):
        ident = unquote(ident)
        if ':' in ident:
            url = 'https://id.acdh.oeaw.ac.at' + ident.split(':', 1)[1]
        elif '/' in ident:
            url = 'https://' + ident
        else:
            url = self.arche_base_url + ident
        if not re.search(self.allowed_locations, url):
            raise ResolverException(f'Location {url} is not allowed {self.allowed_locations}')
        return super(ArcheResolver, self).is_resolvable(url)

    def resolve(self, app, ident, base_uri):
        ident = unquote(ident)
        if ':' in ident:
            return super(ArcheResolver, self).resolve(app, 'https://id.acdh.oeaw.ac.at' + ident.split(':', 1)[1], base_uri)
        elif '/' in ident:
            return super(ArcheResolver, self).resolve(app, 'https://' + ident, base_uri)
        else:
            url = self.arche_base_url + ident
            with closing(requests.head(url)) as response:
                if response.status_code == 401:
                    fp = self.unauthorized_image
                elif response.status_code != 200:
                    raise ResolverException(f'Can not resolve the image')
                else:
                    fp = self._get_arche_path(ident)
            format_ = self._get_file_format(fp)
            return ImageInfo(app=app, src_img_fp=fp, src_format=format_, auth_rules={})

