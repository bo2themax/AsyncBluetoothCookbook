# AsyncBluetooth Cookbook
Here you'll find examples of how to use the [AsyncBluetooth](https://github.com/manolofdez/AsyncBluetooth) package.

# Building in Xcode

To set up the project for building and running in Xcode:

1. Copy the file `CodeSigning.xcconfig.example` and rename it to `CodeSigning.xcconfig` in the project root.
2. Open `CodeSigning.xcconfig` and update the `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER` values to match your Apple Developer account and desired bundle identifier.
3. Open the project in Xcode and build as usual.

This ensures proper code signing and allows you to run the app on your device or simulator.
