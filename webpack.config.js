const webpack = require("webpack");
const path = require("path");
const CompressionPlugin = require("compression-webpack-plugin");
const BundleAnalyzerPlugin = require("webpack-bundle-analyzer")
  .BundleAnalyzerPlugin;
const { CleanWebpackPlugin } = require("clean-webpack-plugin");
const ClosurePlugin = require("closure-webpack-plugin");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const isProduction = process.env.NODE_ENV === "production";
const isNode = process.env.TARGET === "node";
const analyze = process.env.ANALYZE === "true";
const target = isNode ? "node" : "web";

module.exports = {
  target,
  entry: {
    csound: "./src/index.js"
  },
  output: {
    path: isProduction
      ? path.resolve(__dirname, "dist")
      : path.resolve(__dirname, "public"),
    filename: isNode ? "libcsound.node.js" : "libcsound.js",
    globalObject: isProduction ? "window" : "this"
  },
  resolve: {
    alias: {
      "@root": path.resolve(__dirname, "src/"),
      "@module": path.resolve(__dirname, "src/modules/")
    }
  },
  optimization: {
    minimize: isProduction,
    concatenateModules: false
    // minimizer: [
    //   new ClosurePlugin(
    //     {
    //       // mode: "STANDARD"
    //       mode: "AGGRESSIVE_BUNDLE"
    //       // extraCommandArgs: ["--externs src/externs/perf_hoooks.js"]
    //     },
    //     {
    //       languageOut: "ECMASCRIPT_2015"
    //     }
    //   )
    // ],
    // splitChunks: {
    //   minSize: 0
    // }
    // mangleWasmImports: true
  },
  devtool: isProduction ? "hidden-source-map" : "source-map",
  devServer: {
    open: true,
    contentBase: path.resolve(__dirname, "public"),
    inline: false // !isProduction
  },
  // experiments: { asyncWebAssembly: false, importAsync: false },
  module: {
    rules: [
      // { loader: "workerize-loader", options: { inline: true } },
      {
        test: /\.js$/,
        enforce: "pre",
        exclude: /node_modules/,
        loader: "eslint-loader",
        options: {
          configFile: path.resolve(__dirname, ".eslintrc"),
          cache: true
        }
      },
      {
        test: /\.wasm$|\.wasm.zlib$/i,
        type: "javascript/auto",
        use: "arraybuffer-loader"
      },
      {
        test: /\.worklet.js$/i,
        use: {
          loader: "url-loader",
          options: { esModule: false, mimetype: "text/javascript" }
        }
      }
    ]
  },
  plugins: [
    new CleanWebpackPlugin(),
    // new ClosurePlugin.LibraryPlugin({
    //   closureLibraryBase: require.resolve(
    //     "google-closure-library/closure/goog/base"
    //   ),
    //   deps: [
    //     require.resolve("google-closure-library/closure/goog/deps"),
    //     "./deps.js"
    //   ]
    // }),
    new webpack.ProvidePlugin({
      goog: "google-closure-library/closure/goog/base"
    }),
    new webpack.optimize.LimitChunkCountPlugin({
      maxChunks: 1
    })
  ].concat(
    !isProduction ? [new HtmlWebpackPlugin({ template: "./src/dev.html" })] : []
  )
  // .concat(analyze ? [new BundleAnalyzerPlugin()] : [])
};
