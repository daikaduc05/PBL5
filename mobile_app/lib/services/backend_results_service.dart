import '../models/result_models.dart' as result_models;
import 'result_api.dart';

@Deprecated('Use ResultApi directly.')
typedef BackendResultsService = ResultApi;

@Deprecated('Use ResultApiException directly.')
typedef BackendResultsException = ResultApiException;

@Deprecated('Use ResultScreenArgs from result_models.dart directly.')
typedef ResultScreenArgs = result_models.ResultScreenArgs;

@Deprecated('Use ResultSessionDetail from result_models.dart directly.')
typedef ResultSessionSummary = result_models.ResultSessionDetail;

@Deprecated('Use ResultFrameItem from result_models.dart directly.')
typedef ResultFrameSummary = result_models.ResultFrameItem;

@Deprecated('Use FrameResultDetail from result_models.dart directly.')
typedef FrameResultDetail = result_models.FrameResultDetail;

@Deprecated('Use extractResultApiMessage directly.')
String extractBackendMessage(Object error) => extractResultApiMessage(error);
