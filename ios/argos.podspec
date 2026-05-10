Pod::Spec.new do |s|
  s.name             = 'argos'
  s.version          = '0.1.0'
  s.summary          = 'All-seeing Flutter APM and HTTP packet capture plugin.'
  s.description      = <<-DESC
Argos is a Flutter plugin that captures HTTP traffic at the native layer
(NSURLProtocol on iOS, OkHttp Interceptor on Android), records FPS metrics,
and ships an inspector UI with route grouping and curl reproduction.
DESC
  s.homepage         = 'https://github.com/ztlyyznf001/argos'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Argos Contributors' => 'noreply@panoptes.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
