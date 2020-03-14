const webpack = require("webpack");
const path = require("path");
const BundleAnalyzerPlugin = require("webpack-bundle-analyzer")
  .BundleAnalyzerPlugin;
const { CleanWebpackPlugin } = require("clean-webpack-plugin");
const ClosurePlugin = require("closure-webpack-plugin");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const isProduction = process.env.WEBPACK_MODE === "production";
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
      ? path.resolve(__dirname, "lib")
      : path.resolve(__dirname, "public"),
    filename: isNode ? "libcsound.node.js" : "libcsound.js"
  },
  resolve: {
    alias: {
      "@root": path.resolve(__dirname, "src/"),
      "@module": path.resolve(__dirname, "src/modules/")
    }
  },
  optimization: {
    minimize: isProduction,
    minimizer: [
      new ClosurePlugin(
        {
          // mode: "STANDARD"
          mode: "AGGRESSIVE_BUNDLE"
          // extraCommandArgs: ["--externs src/externs/perf_hoooks.js"]
        },
        {
          languageOut: "ECMASCRIPT_2015"
        }
      )
    ],
    splitChunks: {
      minSize: 0
    }
    // concatenateModules: true,
    // mangleWasmImports: true
  },
  devtool: "source-map",
  devServer: {
    open: true,
    contentBase: path.resolve(__dirname, "public"),
    inline: !isProduction
  },
  // experiments: { asyncWebAssembly: false, importAsync: false },
  module: {
    rules: [
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
        test: /\.wasm$/i,
        type: "javascript/auto",
        use: "arraybuffer-loader"
      }
    ]
  },
  plugins: [
    new CleanWebpackPlugin(),
    new ClosurePlugin.LibraryPlugin({
      closureLibraryBase: require.resolve(
        "google-closure-library/closure/goog/base"
      ),
      deps: [
        require.resolve("google-closure-library/closure/goog/deps"),
        "./deps.js"
      ]
    }),
    new webpack.ProvidePlugin({
      goog: "google-closure-library/closure/goog/base"
    }),
    new webpack.optimize.LimitChunkCountPlugin({
      maxChunks: 2
    })
  ]
    .concat(
      !isProduction
        ? [new HtmlWebpackPlugin({ template: "./src/dev.html" })]
        : []
    )
    .concat(analyze ? [new BundleAnalyzerPlugin()] : [])
};
