import sbt._

object Version {
  val serviceLocatorDns = "1.0.1"
}

object Library {
  val serviceLocatorDns = "com.lightbend" %% "lagom-service-locator-dns" % Version.serviceLocatorDns
}
