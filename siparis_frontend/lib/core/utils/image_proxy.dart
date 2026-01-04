String proxiedImageUrl(String url) {
  return 'http://localhost:8000/image-proxy?url=${Uri.encodeComponent(url)}';
}
